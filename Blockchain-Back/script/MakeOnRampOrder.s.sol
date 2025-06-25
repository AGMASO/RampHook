// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {console2} from "forge-std/console2.sol";

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";

import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {Vault} from "../src/Vault.sol";
import {RampHookV1} from "../src/RampHookV1.sol";

contract MakeOnRampOrderScript is Script {
    address private _deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
    // Hardcoded contract addresses (fill these in after deploying the main contracts)
    IPoolManager public constant poolManager =
        IPoolManager(0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408);
    PoolSwapTest public constant swapRouter =
        PoolSwapTest(0x47e2fD55a1D27CB322533c9b0C2AeAcB36d58c72);
    Vault public constant vault =
        Vault(0x8C45cBf71Af067019A62fCfccEc749dF567C9313);
    RampHookV1 public constant rampHook =
        RampHookV1(0xA11C7Faf1b89B9173B5d7137591Ccb51D2F96088);
    // Token addresses - using USDCm and USDTm
    IERC20 constant token0 = IERC20(0x096b36810d4E9243318f0Cd4C18a2dbd1661470C); // USDCm
    IERC20 constant token1 = IERC20(0xC3726B8054f88FD63F9268c0ab21667083D01414); // USDTm

    Currency public currency0;
    Currency public currency1;
    // Pool key details - you'll need to update this with your deployed hook address
    bytes constant ZERO_BYTES = new bytes(0);
    int24 constant tickSpacing = 1;
    IHooks public constant hookContract =
        IHooks(0xA11C7Faf1b89B9173B5d7137591Ccb51D2F96088); // Replace with actual hook address
    address public ONRAMPER = 0xEeCdf10373bdEee9C66150443b63C15B297D6000;

    function run() public {
        vm.startBroadcast(_deployer);
        PoolKey memory key = createPoolKey();
        assert(
            vault.rampHooks(PoolId.unwrap(key.toId())) == address(hookContract)
        );

        vault.approveHook(
            Currency.unwrap(currency0),
            address(hookContract),
            400e6
        );
        vault.approveHook(
            Currency.unwrap(currency0),
            address(hookContract),
            400e6
        );
        uint256 balanceofVaultBeforeOnRamp = IERC20(Currency.unwrap(currency0))
            .balanceOf(address(vault));

        console2.log(
            "Vault currency0 balance before onramp: %s",
            IERC20(Currency.unwrap(currency0)).balanceOf(address(vault))
        );
        console2.log(
            "Vault currency1 balance before onramp: %s",
            IERC20(Currency.unwrap(currency1)).balanceOf(address(vault))
        );
        console2.log(
            "PM currency0 balance before onramp: %s",
            IERC20(Currency.unwrap(currency0)).balanceOf(address(poolManager))
        );
        console2.log(
            "PM currency1 balance before onramp: %s",
            IERC20(Currency.unwrap(currency1)).balanceOf(address(poolManager))
        );
        Vault.OnrampData memory onRampData = Vault.OnrampData({
            amount: 400e6, // 200 USDC
            receiverAddress: address(_deployer), //receiver
            desiredToken: Currency.unwrap(key.currency1) // USDTm
        });

        vault.onramp(onRampData);
        // vault.onramp(onRampData);
        RampHookV1.OnRampOrder[] memory pendingOrders = rampHook
            .getPendingOrders(key.toId(), true);
        console2.log("Pending orders after onramp:", pendingOrders.length);
        console2.log(
            "Vault currency0 balance after onramp: %s",
            IERC20(Currency.unwrap(currency0)).balanceOf(address(vault))
        );
        console2.log(
            "Vault currency1 balance after onramp: %s",
            IERC20(Currency.unwrap(currency1)).balanceOf(address(vault))
        );

        assert(pendingOrders.length >= 1);
        vm.stopBroadcast();
    }
    function createPoolKey() public returns (PoolKey memory) {
        (currency0, currency1) = getCurrencies();

        return
            PoolKey({
                currency0: currency0,
                currency1: currency1,
                fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
                tickSpacing: tickSpacing,
                hooks: hookContract
            });
    }

    function getCurrencies() public pure returns (Currency, Currency) {
        if (address(token0) < address(token1)) {
            return (
                Currency.wrap(address(token0)),
                Currency.wrap(address(token1))
            );
        } else {
            return (
                Currency.wrap(address(token1)),
                Currency.wrap(address(token0))
            );
        }
    }
}
