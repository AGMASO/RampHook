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

contract RampHookV1 is BaseHook, Ownable {
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
    //mapping pendingOrders
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

    /** @notice This function should be called by Vault and in here we need to:
     * 1: introduce the Liquidity to the pool
     * 2: update mappings to track the orders
     */
    function createOnRampOrder(
        SwapParams calldata swapParams,
        address receiver,
        PoolKey calldata key
    ) external onlyVault {
        OnRampOrder memory newOrder = OnRampOrder({
            inputAmount: -swapParams.amountSpecified, //! I'm saving this inputAmount as a positive sign number for a exactinput
            receiver: receiver,
            fulfilled: false
        });

        pendingOrders[key.toId()][swapParams.zeroForOne].push(newOrder);
        //Transfer USDC from the vault to the hook
        if (swapParams.zeroForOne) {
            IERC20Minimal(Currency.unwrap(key.currency0)).transferFrom(
                msg.sender,
                address(this),
                uint256(-swapParams.amountSpecified)
            ); // transferimos USDC desde el vault al hook
        } else if (!swapParams.zeroForOne) {
            IERC20Minimal(Currency.unwrap(key.currency1)).transferFrom(
                msg.sender,
                address(this),
                uint256(-swapParams.amountSpecified)
            ); // transferimos USDC desde el vault al hook
        }
        emit OnRampOrderCreated(
            swapParams.zeroForOne,
            receiver,
            swapParams.amountSpecified
        );
    }
    //  /** Before Swap function
    //  *  1. I need to determine which Order the swapper is executing.
    //  *  2. Compare it with the stored order.
    //  *  3. If they are counterparts, then I must create a BalanceSwapDelta
    //  *  that suppresses the PM swap action.
    //  *  4. If they are not counterparts, because there is no OnRamp order that conicides with the swap,
    //  *  then the swap should proceed normally.
    //  */
    function _beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        PoolId poolId = key.toId();

        //Obtain the pool price
        (, int24 currentTick, , ) = poolManager.getSlot0(poolId);
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(currentTick);
        uint256 price = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) /
            (1 << 192);
        console2.log("This is the pool price:", price); //! this is a Q64.96 price, we convert it to Q18

        //!I get Stack too deep errors. Im blocked to use more local variables, any solution??
        // bool oppositeDirection = !params.zeroForOne;

        OnRampOrder[] storage _pendingOrders = pendingOrders[poolId][
            !params.zeroForOne
        ]; //pull all the orders that are oposite direction to the swap by the user
        if (_pendingOrders.length == 0) {
            return (
                this.beforeSwap.selector,
                BeforeSwapDeltaLibrary.ZERO_DELTA, //!Is that correct??
                0
            );
        }
        for (uint256 i = 0; i < _pendingOrders.length; i++) {
            OnRampOrder storage order = _pendingOrders[i];

            if (!order.fulfilled) {
                // int256 expectedOutput = (order.inputAmount * int256(price)) /
                //     1e18;
                int256 expectedOutput = order.inputAmount; //! For testing Purposes of version, we assume 1:1
                console2.log("This is expectedOutput:", expectedOutput);
                console2.log("This is order.inputAmount:", order.inputAmount);
                console2.log(
                    "This is params.amountSpecified:",
                    -params.amountSpecified
                );

                if (-params.amountSpecified == expectedOutput) {
                    int128 absInputAmount = int128(order.inputAmount);
                    int128 absOutputAmount = int128(params.amountSpecified);

                    BeforeSwapDelta beforeSwapDelta = toBeforeSwapDelta(
                        absInputAmount,
                        absOutputAmount
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

        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
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
