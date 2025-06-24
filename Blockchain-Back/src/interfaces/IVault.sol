// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";

/**
 * @title Vault Interface
 * @author 0xagmaso
 * @notice Interface for the Vault contract, which manages ramp hooks and pool keys for on-ramp operations.
 * @dev Defines events, errors, structs, and functions for the Vault contract.
 */
interface IVault {
    /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when an onramp operation is executed
     * @param amount Amount of tokens processed in the onramp
     * @param receiverAddress Address that will receive the tokens
     * @param desiredToken Token that the user wants to receive
     */
    event OnrampExecuted(
        int256 amount,
        address indexed receiverAddress,
        address indexed desiredToken
    );

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Throws if the ramp hook is not set for a pool with currency0 and currency1 stored in the mapping
     * @dev This error is thrown when trying to execute an onramp without a configured a pool to a PoolKey
     */
    error Vault_RampHookNotSet();

    /*///////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/

    /*///////////////////////////////////////////////////////////////
                            FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets a whitelisted ramp hook for a specific pool
     * @dev Only callable by the contract owner
     * @param key Pool key identifying the pool and its hook
     */
    function setWhiteListRampHook(PoolKey calldata key) external;

    /**
     * @notice Sets the pool key for a token pair
     * @dev Only callable by the contract owner
     * @param token0 First token address (sorted)
     * @param token1 Second token address (sorted)
     * @param key Pool key for the token pair
     */
    function setPoolKey(
        address token0,
        address token1,
        PoolKey calldata key
    ) external;

    /**
     * @notice Retrieves the ramp hook address for a given pool key
     * @param key Pool key identifying the pool
     * @return address Address of the ramp hook for the pool
     */
    function getRampHook(PoolKey calldata key) external view returns (address);

    /**
     * @notice Approves a hook to spend tokens on behalf of the vault
     * @dev Only callable by the contract owner
     * @param token Token address to approve
     * @param hook Hook address to approve
     * @param amount Amount of tokens to approve
     */
    function approveHook(address token, address hook, uint256 amount) external;
}
