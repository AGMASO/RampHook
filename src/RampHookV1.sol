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
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";

contract RampHookV1 is BaseHook, Ownable {
    error RampHook_MustUseDynamicFee();

    using CurrencySettler for Currency;
    using StateLibrary for IPoolManager;
    using LPFeeLibrary for uint24;

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
                beforeInitialize: true,
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

    function _beforeInitialize(
        address,
        PoolKey calldata key,
        uint160
    ) internal pure override returns (bytes4) {
        // `.isDynamicFee()` function comes from using
        // the `LPFeeLibrary` for `uint24`
        if (!key.fee.isDynamicFee()) revert RampHook_MustUseDynamicFee();
        return this.beforeInitialize.selector;
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
            // function settle(Currency currency, IPoolManager manager, address payer, uint256 amount, bool burn) internal {
            //!aqui estamos enviano Token0 al PM en el caso de que sea zeroForOne
            key.currency0.settle(
                poolManager,
                sender,
                uint256(-swapParams.amountSpecified),
                false
            );
            // function take(Currency currency, IPoolManager manager, address recipient, uint256 amount, bool claims) internal {
            //! Estamos dando Claims TOkens por los tokens enviados al Hook
            key.currency0.take(
                poolManager,
                address(this),
                uint256(-swapParams.amountSpecified),
                true
            );
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
        //Obtain the pool price
        (, int24 currentTick, , ) = poolManager.getSlot0(key.toId());
        uint256 price = _tickToPrice(currentTick);
        console2.log("Esto es el precio de la pool:", price); //! esto es un precio Q64.96, lo convertimos a Q18
        int256 expectedOut = _getExpectedOutput(-params.amountSpecified, price);
        console2.log("Esto es el expectedOutput del swap:", expectedOut);
        // bool oppositeDirection = !params.zeroForOne; //! vamos a buscar solo los orders opuestos al swap entrante

        return _matchOrders(key, params, expectedOut);
    }

    function _settleAndTake(
        PoolKey memory key,
        bool zeroForOne,
        int128 inputAmount,
        int128 outputAmount,
        address onRamperReceiver
    ) internal {
        (Currency userSellToken, Currency userBuyToken) = zeroForOne
            ? (key.currency0, key.currency1)
            : (key.currency1, key.currency0);
        //! se acunan claimsTokens0 al Hook
        userSellToken.take(
            poolManager,
            address(this),
            uint256(uint128(inputAmount)),
            true
        );
        //!Quema los claimtoknes1 de Hook.
        userBuyToken.settle(
            poolManager,
            address(this),
            uint256(uint128(-outputAmount)),
            true
        );

        //!Transfers Token0 to the Hook, then we settle and finally send from the Hook to user1
        userSellToken.take(
            poolManager,
            address(this),
            uint256(uint128(-outputAmount)),
            false
        );
        userSellToken.settle(
            poolManager,
            address(this),
            uint256(uint128(-outputAmount)),
            true
        );
        IERC20Minimal(Currency.unwrap(userSellToken)).transfer(
            onRamperReceiver,
            uint256(uint128(-outputAmount))
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
    function _tickToPrice(int24 currentTick) public pure returns (uint256) {
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(currentTick);
        // Convertir sqrtPriceX96 a un precio decimal (por ejemplo, Q64.96 a Q18)
        return (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) / (1 << 192);
    }

    function _getExpectedOutput(
        int256 _amountSpecified,
        uint256 _price
    ) private pure returns (int256 expectedOutput) {
        expectedOutput = (_amountSpecified * int256(_price));
    }

    //! Lo que funciona...
    function _matchOrders(
        PoolKey calldata key,
        SwapParams calldata params,
        int256 expectedOut
    ) private returns (bytes4, BeforeSwapDelta, uint24) {
        OnRampOrder[] storage orders = pendingOrders[key.toId()][
            !params.zeroForOne
        ];

        int256 remOut = expectedOut; // output que falta entregar
        int256 matched0; // token0 ya liquidado por Hook
        int256 matched1; // token1 ya liquidado por Hook

        for (uint256 i; i < orders.length && remOut > 0; ++i) {
            OnRampOrder storage order = orders[i];
            if (order.fulfilled) continue;

            int256 takeOut = order.inputAmount <= remOut
                ? order.inputAmount
                : remOut;

            // proporción de token0 que hace falta para cubrir `takeOut`
            int256 takeIn = (takeOut * -params.amountSpecified) / expectedOut;

            _settleAndTake(
                key,
                params.zeroForOne,
                int128(takeIn),
                int128(-takeOut),
                order.receiver
            );

            matched0 += takeIn; // acumulamos para el delta
            matched1 -= takeOut;

            remOut -= takeOut;
            if (order.inputAmount <= takeOut) order.fulfilled = true;
        }

        // Δ que le indica al núcleo lo que YA liquidó el Hook
        BeforeSwapDelta deltaHook = matched0 == 0
            ? BeforeSwapDeltaLibrary.ZERO_DELTA
            : toBeforeSwapDelta(int128(matched0), int128(matched1));

        uint24 fee = matched0 == 0 ? 5000 : 60000;
        uint24 feeWithFlag = fee | LPFeeLibrary.OVERRIDE_FEE_FLAG;
        return (this.beforeSwap.selector, deltaHook, feeWithFlag);
    }
}
