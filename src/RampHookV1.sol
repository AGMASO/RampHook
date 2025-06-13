// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console2} from "forge-std/Test.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary, toBeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {StateLibrary} from "v4-periphery/lib/v4-core/src/libraries/StateLibrary.sol";
import {TickMath} from "v4-periphery/lib/v4-core/src/libraries/TickMath.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IRampHookV1} from "./interfaces/IRampHookV1.sol";
import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";

contract RampHookV1 is BaseHook, Ownable {
    using CurrencySettler for Currency;
    using StateLibrary for IPoolManager;

    // using FixedPointMathLib for uint256;

    address private s_vault;

    error OnlyVaultCanCreateOnRampOrder();
    event OnRampOrderCreated(
        bool zeroForOne,
        address receiver,
        int256 amountSpecified
    );
    struct OnRampOrder {
        int256 inputAmount;
        address receiver;
        bool fulfilled;
    }
    //mapping que genera las pendignOrders
    mapping(PoolId poolId => mapping(bool zeroForOne => OnRampOrder[]))
        public pendingOrders;

    constructor(
        IPoolManager _poolManager,
        address _vault
    ) BaseHook(_poolManager) Ownable(msg.sender) {
        require(_vault != address(0), "Vault address cannot be zero");
        s_vault = _vault;
    }

    modifier onlyVault() {
        if (msg.sender != address(s_vault)) {
            revert OnlyVaultCanCreateOnRampOrder();
        }
        _;
    }

    struct CallbackData {
        SwapParams swapParams;
        address receiver;
        address sender;
        PoolKey key;
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: true,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    /** @notice This function should be called by Vault and in hee we need to:
     * 1: introduce the Liquidity to the pool
     * 2: update mappings to track the orders
     * 3:
     *
     */
    function createOnRampOrder(
        SwapParams calldata swapParams,
        address receiver,
        PoolKey calldata key
    ) external onlyVault {
        poolManager.unlock(
            abi.encode(CallbackData(swapParams, receiver, msg.sender, key))
        );
    }

    function unlockCallback(
        bytes calldata data
    ) external onlyPoolManager returns (bytes memory) {
        CallbackData memory callbackData = abi.decode(data, (CallbackData));
        SwapParams memory swapParams = callbackData.swapParams;
        address receiver = callbackData.receiver;
        address sender = callbackData.sender;
        PoolKey memory key = callbackData.key;

        OnRampOrder memory newOrder = OnRampOrder({
            inputAmount: -swapParams.amountSpecified, //! lo estamos guardadon en positivo
            receiver: receiver,
            fulfilled: false
        });

        pendingOrders[key.toId()][swapParams.zeroForOne].push(newOrder); // esto esta en negativo
        if (swapParams.zeroForOne) {
            key.currency0.settle(
                poolManager,
                sender,
                uint256(-swapParams.amountSpecified),
                false
            );
            key.currency0.take(
                poolManager,
                address(this),
                uint256(-swapParams.amountSpecified),
                true
            );
            // IERC20Minimal(Currency.unwrap(key.currency0)).transferFrom(
            //     msg.sender,
            //     address(this),
            //     uint256(-swapParams.amountSpecified)
            // ); // transferimos USDC desde el vault al hook
        } else if (!swapParams.zeroForOne) {
            key.currency1.settle(
                poolManager,
                sender,
                uint256(-swapParams.amountSpecified),
                false
            );
            key.currency1.take(
                poolManager,
                address(this),
                uint256(-swapParams.amountSpecified),
                true
            );
            // IERC20Minimal(Currency.unwrap(key.currency1)).transferFrom(
            //     msg.sender,
            //     address(this),
            //     uint256(-swapParams.amountSpecified)
            // ); // transferimos USDC desde el vault al hook
        }
        emit OnRampOrderCreated(
            swapParams.zeroForOne,
            receiver,
            swapParams.amountSpecified
        );
    }

    // function beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
    function _beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        // /**
        //  *  1. Tengo que sacar que Order esta haciendo el swapper
        //  *  2. comparar con el order que tengo guardado
        //  *  3. si son contrapartida, entocnes debo crear un BalanceSwapDelta que
        //  *  suprima la accion de PM swap
        //  * 4. si no son contrapartida, porque no hay un order Onramp entocnes que el swap se
        //  *  haga de forma normal.
        //  */

        //Obtain the pool price
        (, int24 currentTick, , ) = poolManager.getSlot0(key.toId());
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(currentTick);
        // Convertir sqrtPriceX96 a un precio decimal (por ejemplo, Q64.96 a Q18)
        uint256 price = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) /
            (1 << 192);
        console2.log("Esto es el precio de la pool:", price); //! esto es un precio Q64.96, lo convertimos a Q18

        // bool oppositeDirection = !params.zeroForOne; //! vamos a buscar solo los orders opuestos al swap entrante

        if (pendingOrders[key.toId()][!params.zeroForOne].length == 0) {
            return (
                this.beforeSwap.selector,
                BeforeSwapDeltaLibrary.ZERO_DELTA,
                0
            );
        }
        for (
            uint256 i = 0;
            i < pendingOrders[key.toId()][!params.zeroForOne].length;
            i++
        ) {
            OnRampOrder storage order = pendingOrders[key.toId()][
                !params.zeroForOne
            ][i];

            if (!order.fulfilled) {
                // int256 expectedOutput = (order.inputAmount * int256(price)) /
                //     1e18; //!aqui puede estar mal
                console2.log("Esto es expectedOutput:", order.inputAmount);
                console2.log("Esto es order.inputAmount:", order.inputAmount);
                console2.log(
                    "Esto es params.amountSpecified:",
                    -params.amountSpecified
                );

                if (-params.amountSpecified == order.inputAmount) {
                    int128 inputAmount = int128(order.inputAmount);
                    int128 outputAmount = int128(params.amountSpecified);

                    BeforeSwapDelta beforeSwapDelta = toBeforeSwapDelta(
                        inputAmount,
                        outputAmount
                    );

                    _settleAndTake(
                        key,
                        params.zeroForOne,
                        inputAmount,
                        outputAmount
                    );

                    //!Should i transfer the tokens between them here??
                    // IERC20Minimal(Currency.unwrap(key.currency0)).transferFrom(
                    //     sender,
                    //     address(this),
                    //     uint256(params.amountSpecified)
                    // );

                    // IERC20Minimal(Currency.unwrap(key.currency1)).transfer(
                    //     order.receiver,
                    //     uint256(order.inputAmount)
                    // );

                    order.fulfilled = true;
                    return (this.beforeSwap.selector, beforeSwapDelta, 0);
                }
            }
        }
        console2.log("Estoy aqui");
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0); //sigue
    }

    function _settleAndTake(
        PoolKey memory key,
        bool zeroForOne,
        int128 inputAmount,
        int128 outputAmount
    ) internal {
        (Currency userSellToken, Currency userBuyToken) = zeroForOne
            ? (key.currency0, key.currency1)
            : (key.currency1, key.currency0);
        userSellToken.take(
            poolManager,
            address(this),
            uint256(uint128(inputAmount)),
            true
        );
        userBuyToken.settle(
            poolManager,
            address(this),
            uint256(uint128(-outputAmount)),
            true
        );
    }

    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "Vault address cannot be zero");
        s_vault = _vault;
    }

    function getPendingOrders(
        PoolId poolId,
        bool zeroForOne
    ) external view returns (OnRampOrder[] memory) {
        return pendingOrders[poolId][zeroForOne];
    }
}
