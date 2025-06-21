// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console2} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {BaseScript} from "./base/BaseScript.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {RampHookV1} from "../src/RampHookV1.sol";
import {Vault} from "../src/Vault.sol";

contract TestOnRampScript is BaseScript {
    using CurrencyLibrary for Currency;

    uint256 private pk = vm.envUint("PRIVATE_KEY");
    address private _deployer = vm.addr(pk);

    // Test address users
    address USER1 = makeAddr("USER1");
    address USER2 = makeAddr("USER2");

    // Vault y Hook addresses
    address vaultAddress;
    address hookAddress;

    // Pool details
    PoolKey poolKey;
    PoolId poolId;

    function run() external {
        // Initialize deployer and tokens
        deployerAddress = getDeployer();
        console2.log("Deployer address:", deployerAddress);

        vm.startBroadcast(_deployer);

        console2.log("Tokens deployed for OnRamp test");
        console2.log("Token0 address:", address(token0));
        console2.log("Token1 address:", address(token1));

        // Create Currency objects
        (currency0, currency1) = getCurrencies();
        console2.log("Currency0:", Currency.unwrap(currency0));
        console2.log("Currency1:", Currency.unwrap(currency1));

        // Locate vault and hook from deployed addresses
        hookAddress = address(hookContract);
        console2.log("Hook address:", hookAddress);

        vaultAddress = address(vault);
        console2.log("New vault deployed at:", vaultAddress);

        // Setup pool key
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 1,
            hooks: hookContract
        });
        poolId = poolKey.toId();

        // Configure Vault
        vault.setWhiteListRampHook(poolKey);
        vault.setPoolKey(
            Currency.unwrap(currency0),
            Currency.unwrap(currency1),
            poolKey
        );

        // Mint tokens to test users
        token0.mint(USER1, 3000e6);
        token1.mint(USER1, 3000e6);
        token0.mint(USER2, 3000e6);
        token1.mint(USER2, 3000e6);
        console2.log("Tokens minted to test users");
        console2.log("USER1 token0 balance:", token0.balanceOf(USER1));
        console2.log("USER1 token1 balance:", token1.balanceOf(USER1));
        console2.log("USER2 token0 balance:", token0.balanceOf(USER2));
        console2.log("USER2 token1 balance:", token1.balanceOf(USER2));

        vm.stopBroadcast();

        // Start testing OnRamp functionality
        console2.log("\n--- Testing OnRamp Functionality ---");

        // Transfer tokens from USER1 to Vault
        console2.log("Current sender: ", block.coinbase);
        vm.startPrank(USER1);
        token1.approve(vaultAddress, 3000e6);
        token1.transfer(vaultAddress, 3000e6);
        vm.stopPrank();

        console2.log(
            "Vault currency0 balance before onramp:",
            currency0.balanceOf(vaultAddress)
        );
        console2.log(
            "Vault currency1 balance before onramp:",
            currency1.balanceOf(vaultAddress)
        );
        console2.log(
            "PM currency0 balance before onramp:",
            currency0.balanceOf(address(poolManager))
        );
        console2.log(
            "PM currency1 balance before onramp:",
            currency1.balanceOf(address(poolManager))
        );

        // Execute onramp
        vm.startPrank(deployerAddress); // Only deployer can call vault functions
        Vault.OnrampData memory onRampData = Vault.OnrampData({
            amount: 200e6, // 200 tokens (using correct decimals)
            receiverAddress: USER1,
            desiredToken: Currency.unwrap(currency0)
        });

        Vault(vaultAddress).onramp(onRampData);
        vm.stopPrank();

        console2.log("\n--- After OnRamp ---");
        console2.log(
            "Hook currency0 balance:",
            currency0.balanceOf(hookAddress)
        );
        console2.log(
            "Hook currency1 balance:",
            currency1.balanceOf(hookAddress)
        );
        console2.log(
            "Vault currency0 balance:",
            currency0.balanceOf(vaultAddress)
        );
        console2.log(
            "Vault currency1 balance:",
            currency1.balanceOf(vaultAddress)
        );
        console2.log(
            "PM currency0 balance:",
            currency0.balanceOf(address(poolManager))
        );
        console2.log(
            "PM currency1 balance:",
            currency1.balanceOf(address(poolManager))
        );
        console2.log(
            "Hook Claims0 balance:",
            poolManager.balanceOf(hookAddress, currency0.toId())
        );
        console2.log(
            "Hook Claims1 balance:",
            poolManager.balanceOf(hookAddress, currency1.toId())
        );

        // Check pending orders
        RampHookV1 hook = RampHookV1(hookAddress);
        RampHookV1.OnRampOrder[] memory pendingOrders = hook.getPendingOrders(
            poolId,
            false
        );
        console2.log("Pending orders length:", pendingOrders.length);

        // USER2 performs a swap to match the order
        console2.log("\n--- USER2 Swap to Match Order ---");
        vm.startPrank(USER2);

        // Approve tokens for swap
        token0.approve(address(swapRouter), 300e6);
        // function swap(
        //     int256 amountSpecified,
        //     uint256 amountLimit,
        //     bool zeroForOne,
        //     PoolKey calldata poolKey,
        //     bytes calldata hookData,
        //     address receiver,
        //     uint256 deadline
        // ) external payable returns (BalanceDelta);

        // Create swap router and perform the swap
        // PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
        //     takeClaims: false,
        //     settleUsingBurn: false
        // });
        swapRouter.swap({
            amountSpecified: -200e6, // Negative for exact input swap
            amountLimit: 0, // No limit on output
            zeroForOne: true, // Swap currency0 for currency1
            poolKey: poolKey,
            hookData: new bytes(0), // No hook data needed for this test
            receiver: USER2,
            deadline: block.timestamp + 1 // Short deadline for testing
        });

        // swapRouter.swap(
        //     poolKey,
        //     SwapParams({
        //         zeroForOne: true,
        //         amountSpecified: -200e6,
        //         sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        //     }),
        //     settings,
        //     new bytes(0)
        // );
        vm.stopPrank();

        console2.log("\n--- After Swap Match ---");
        console2.log(
            "Hook currency0 balance:",
            currency0.balanceOf(hookAddress)
        );
        console2.log(
            "Hook currency1 balance:",
            currency1.balanceOf(hookAddress)
        );
        console2.log(
            "Vault currency0 balance:",
            currency0.balanceOf(vaultAddress)
        );
        console2.log(
            "Vault currency1 balance:",
            currency1.balanceOf(vaultAddress)
        );
        console2.log("USER1 currency0 balance:", currency0.balanceOf(USER1));
        console2.log("USER1 currency1 balance:", currency1.balanceOf(USER1));
        console2.log("USER2 currency0 balance:", currency0.balanceOf(USER2));
        console2.log("USER2 currency1 balance:", currency1.balanceOf(USER2));

        // Check pending orders again
        pendingOrders = hook.getPendingOrders(poolId, false);
        console2.log("Pending orders after match:", pendingOrders.length);
    }
}
