// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console2} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
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
import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";

import {IRampHookV1} from "./interfaces/IRampHookV1.sol";

contract RampHookV1 is IRampHookV1, BaseHook, Ownable {
    using CurrencySettler for Currency;
    using StateLibrary for IPoolManager;
    using LPFeeLibrary for uint24;
    uint24 constant NORMAL_SWAP_FEE = 5000; // 0.5% fee
    uint24 constant HIGH_SWAP_FEE = 60000; // 6% fee

    address private s_vault;
    /// @notice mapping to store pending on-ramp orders
    mapping(PoolId poolId => mapping(bool zeroForOne => OnRampOrder[]))
        public pendingOrders;

    constructor(
        IPoolManager _poolManager,
        address _vault
    ) BaseHook(_poolManager) Ownable(msg.sender) {
        require(_vault != address(0), "Vault address cannot be zero");
        s_vault = _vault;
    }
    /// @notice modifier to restrict actions to the vault only
    modifier onlyVault() {
        if (msg.sender != address(s_vault)) {
            revert RampHook_OnlyVaultCanCreateOnRampOrder();
        }
        _;
    }
    /// @inheritdoc BaseHook
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
    /// @inheritdoc BaseHook
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

    /// @inheritdoc IRampHookV1
    function createOnRampOrder(
        SwapParams calldata swapParams,
        address receiver,
        PoolKey calldata key
    ) external onlyVault {
        poolManager.unlock(
            abi.encode(CallbackData(swapParams, receiver, msg.sender, key))
        );
    }

    /// @inheritdoc IRampHookV1
    function unlockCallback(
        bytes calldata data
    ) external onlyPoolManager returns (bytes memory) {
        CallbackData memory callbackData = abi.decode(data, (CallbackData));
        SwapParams memory swapParams = callbackData.swapParams;
        address receiver = callbackData.receiver;
        address sender = callbackData.sender;
        PoolKey memory key = callbackData.key;

        OnRampOrder memory newOrder = OnRampOrder({
            inputAmount: int256(-swapParams.amountSpecified), //! storing as a positive value
            receiver: receiver,
            fulfilled: false
        });

        pendingOrders[key.toId()][swapParams.zeroForOne].push(newOrder); // esto esta en negativo
        if (swapParams.zeroForOne) {
            // function settle(Currency currency, IPoolManager manager, address payer, uint256 amount, bool burn) internal {
            //! Here we are sending Token0 to the Pool Manager in the case of zeroForOne
            key.currency0.settle(
                poolManager,
                sender,
                uint256(-swapParams.amountSpecified),
                false
            );
            // function take(Currency currency, IPoolManager manager, address recipient, uint256 amount, bool claims) internal {
            //! We are issuing Claim Tokens for the tokens sent to the Hook
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
    /// @inheritdoc IRampHookV1
    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "Vault address cannot be zero");
        s_vault = _vault;
    }
    /// @inheritdoc BaseHook
    function _beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        //Obtain the pool price
        (, int24 currentTick, , ) = poolManager.getSlot0(key.toId());
        uint256 price = _tickToPrice(currentTick);
        console2.log("This is the pool price:", price);
        int256 expectedOut = _getExpectedOutput(-params.amountSpecified, price);
        console2.log("This is the expected output of the swap:", expectedOut);

        return _matchOrders(key, params, expectedOut);
    }
    /**
     * @notice Settles the swap and takes the output amount
     * @dev This function is called to finalize the swap and transfer tokens to the receiver
     * @param key Pool key identifying the pool
     * @param zeroForOne Direction of the swap (true if swapping token0 for token1)
     * @param inputAmount Amount of input tokens for the swap
     * @param outputAmount Amount of output tokens to be taken
     * @param onRamperReceiver Address that will receive the output tokens
     */
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
        //! claimTokens0 are minted to the Hook
        userSellToken.take(
            poolManager,
            address(this),
            uint256(uint128(inputAmount)),
            true
        );
        //!Burns the claimTokens1 from the Hook.
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

    /**
     * @notice Matches orders in the pool
     * @dev This function is called to execute the swap and fulfill the on-ramp order
     * @param key Pool key identifying the pool
     * @param params Swap parameters for the operation
     * @param expectedOut Expected output amount from the swap
     * @return bytes4 Selector for the callback function
     * @return BeforeSwapDelta Delta amounts before the swap
     * @return uint24 The fee tier of the pool used for the swap
     */
    function _matchOrders(
        PoolKey calldata key,
        SwapParams calldata params,
        int256 expectedOut
    ) private returns (bytes4, BeforeSwapDelta, uint24) {
        OnRampOrder[] storage orders = pendingOrders[key.toId()][
            !params.zeroForOne
        ];

        /**
         * @dev Tracks the remaining output amount that needs to be delivered.
         * @param remOut The amount of output tokens still to be delivered.
         *
         * @dev Tracks the amount of token0 and token1 already settled by the Hook.
         * @param matched0 The amount of token0 that has been liquidated by the Hook.
         * @param matched1 The amount of token1 that has been liquidated by the Hook.
         */
        int256 remOut = expectedOut;
        int256 matched0;
        int256 matched1;

        for (uint256 i; i < orders.length && remOut > 0; ++i) {
            OnRampOrder storage order = orders[i];
            if (order.fulfilled) continue;

            int256 takeOut = order.inputAmount <= remOut
                ? order.inputAmount
                : remOut;

            // proportion of token0 needed to cover `takeOut`
            int256 takeIn = (takeOut * -params.amountSpecified) / expectedOut;

            _settleAndTake(
                key,
                params.zeroForOne,
                int128(takeIn),
                int128(-takeOut),
                order.receiver
            );

            matched0 += takeIn; // accumulate for the delta
            matched1 -= takeOut;

            remOut -= takeOut;
            if (order.inputAmount <= takeOut) order.fulfilled = true;
        }

        BeforeSwapDelta deltaHook = matched0 == 0
            ? BeforeSwapDeltaLibrary.ZERO_DELTA
            : toBeforeSwapDelta(int128(matched0), int128(matched1));

        uint24 fee = matched0 == 0 ? NORMAL_SWAP_FEE : HIGH_SWAP_FEE;
        uint24 feeWithFlag = fee | LPFeeLibrary.OVERRIDE_FEE_FLAG;
        return (this.beforeSwap.selector, deltaHook, feeWithFlag);
    }
    /// @notice Calculates the expected output amount based on the input amount and price
    function _getExpectedOutput(
        int256 _amountSpecified,
        uint256 _price
    ) private pure returns (int256 expectedOutput) {
        expectedOutput = (_amountSpecified * int256(_price)) / 1e18;
    }
    /// @inheritdoc IRampHookV1
    function getPendingOrders(
        PoolId poolId,
        bool zeroForOne
    ) external view returns (OnRampOrder[] memory) {
        return pendingOrders[poolId][zeroForOne];
    }

    /// @inheritdoc IRampHookV1
    function _tickToPrice(int24 currentTick) public pure returns (uint256) {
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(currentTick);
        uint256 num = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);

        return (num * 1e18) >> 192;
    }
}
