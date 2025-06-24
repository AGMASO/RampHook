// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";

/**
 * @title RampHookV1 Interface
 * @author Your Name
 * @notice Interface for the RampHookV1 contract, which manages on-ramp orders and token swaps in Uniswap V4 pools.
 * @dev Defines events, errors, structs, and functions for the RampHookV1 contract.
 */
interface IRampHookV1 {
    /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a new on-ramp order is created
     * @param zeroForOne Direction of the swap (true if swapping token0 for token1)
     * @param receiver Address that will receive the tokens
     * @param amountSpecified Amount of tokens specified for the swap
     */
    event OnRampOrderCreated(
        bool zeroForOne,
        address receiver,
        int256 amountSpecified
    );

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Throws if the pool doesn't use dynamic fees
     * @dev This error is thrown when trying to initialize a pool without dynamic fee capability
     */
    error RampHook_MustUseDynamicFee();

    /**
     * @notice Throws if caller is not the authorized vault
     * @dev This error is thrown when a non-vault address tries to create an on-ramp order
     */
    error RampHook_OnlyVaultCanCreateOnRampOrder();

    /*///////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Structure representing an on-ramp order
     * @param inputAmount Amount of input tokens for the order
     * @param receiver Address that will receive the output tokens
     * @param fulfilled Whether the order has been fulfilled
     */
    struct OnRampOrder {
        int256 inputAmount;
        address receiver;
        bool fulfilled;
    }

    /**
     * @notice Structure for callback data used in unlock operations
     * @param swapParams Parameters for the swap operation
     * @param receiver Address that will receive the tokens
     * @param sender Address that initiated the operation
     * @param key Pool key identifying the pool
     */
    struct CallbackData {
        SwapParams swapParams;
        address receiver;
        address sender;
        PoolKey key;
    }

    /*///////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new on-ramp order
     * @dev Only callable by the authorized vault
     * @param swapParams Parameters for the swap operation
     * @param receiver Address that will receive the tokens
     * @param key Pool key identifying the pool
     */
    function createOnRampOrder(
        SwapParams calldata swapParams,
        address receiver,
        PoolKey calldata key
    ) external;

    /**
     * @notice Callback function called during unlock operations
     * @dev This function is called by the pool manager during unlock
     * @param data Encoded callback data containing swap parameters
     * @return bytes Empty return data
     */
    function unlockCallback(
        bytes calldata data
    ) external returns (bytes memory);

    /**
     * @notice Sets the vault address that can create on-ramp orders
     * @dev Only callable by the contract owner
     * @param _vault New vault address
     */
    function setVault(address _vault) external;

    /**
     * @notice Retrieves pending orders for a specific pool and direction
     * @param poolId ID of the pool
     * @param zeroForOne Direction of the orders to retrieve
     * @return OnRampOrder[] Array of pending orders
     */
    function getPendingOrders(
        PoolId poolId,
        bool zeroForOne
    ) external view returns (OnRampOrder[] memory);

    /**
     * @notice Converts a tick value to a price
     * @dev Converts from tick format to a decimal price representation
     * @param currentTick The tick value to convert
     * @return uint256 The price in decimal format
     */
    function _tickToPrice(int24 currentTick) external pure returns (uint256);
}
