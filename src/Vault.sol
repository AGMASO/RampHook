// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {RampHookV1} from "./RampHookV1.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

contract Vault is Ownable {
    error Vault_RampHookNotSet();
    event OnrampExecuted(
        int256 amount,
        address indexed receiverAddress,
        address indexed desiredToken
    );
    address private constant usdcTokenAddress =
        0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC token address on Base mainnet
    mapping(bytes32 poolId => address rampHookAddress) public rampHooks;
    mapping(address token0 => mapping(address token1 => PoolKey key))
        public poolKeysByTokenPair;

    struct OnrampData {
        int256 amount;
        address receiverAddress;
        address desiredToken;
    }

    constructor() Ownable(msg.sender) {}
    receive() external payable {}

    function setWhiteListRampHook(PoolKey calldata key) external onlyOwner {
        bytes32 poolId = PoolId.unwrap(key.toId());
        address hook = address(key.hooks);
        require(poolId > 0, "RampHookV1: PoolKey poolId cannot be empty");
        require(hook != address(0), "RampHookV1: Hook address cannot be zero");

        rampHooks[poolId] = hook;
    }
    function setPoolKey(
        address token0,
        address token1,
        PoolKey calldata key
    ) external onlyOwner {
        require(
            token0 != address(0) && token1 != address(0),
            "Token addresses cannot be zero"
        );
        require(
            PoolId.unwrap(key.toId()) != bytes32(0),
            "PoolKey toId cannot be empty"
        );

        poolKeysByTokenPair[token0][token1] = key;
    }

    /// @notice Function to handle onramp operations. Sending USDC to the Hook and creating an order
    function onramp(OnrampData memory _onrampData) external onlyOwner {
        require(_onrampData.amount > 0, "Amount must be greater than zero");
        require(
            _onrampData.receiverAddress != address(0),
            "Receiver address cannot be zero"
        );
        require(
            _onrampData.desiredToken != address(0),
            "Desired token cannot be zero"
        );
        (address token0, address token1) = _sortTokens(
            usdcTokenAddress,
            _onrampData.desiredToken
        );
        //calculamos el key para estos tokens 0 y 1
        PoolKey memory key = poolKeysByTokenPair[token0][token1];
        //obtenemos el hook address
        address rampHookAddress = rampHooks[PoolId.unwrap(key.toId())];
        if (rampHookAddress == address(0)) {
            revert Vault_RampHookNotSet();
        }

        SwapParams memory swapParams = SwapParams({
            zeroForOne: token0 == usdcTokenAddress ? true : false,
            amountSpecified: -(int256(_onrampData.amount)),
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
        });

        RampHookV1(rampHookAddress).createOnRampOrder(
            swapParams,
            _onrampData.receiverAddress,
            key
        );

        emit OnrampExecuted(
            _onrampData.amount,
            _onrampData.receiverAddress,
            _onrampData.desiredToken
        );
    }
    function _sortTokens(
        address token0,
        address token1
    ) internal pure returns (address, address) {
        return token0 < token1 ? (token0, token1) : (token1, token0);
    }
    function getRampHook(PoolKey calldata key) external view returns (address) {
        return rampHooks[PoolId.unwrap(key.toId())];
    }
}
