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

contract MakeSwap is Script {
    address private swapper = vm.addr(vm.envUint("PKSWAPPER"));
    // Hardcoded contract addresses (fill these in after deploying the main contracts)
    IPoolManager public constant poolManager =
        IPoolManager(0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408); // Replace with actual address
    PoolSwapTest public constant swapRouter =
        PoolSwapTest(0x47e2fD55a1D27CB322533c9b0C2AeAcB36d58c72); // Replace with deployed address

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

    function run() public {
        console2.log("Starting swap as account:", swapper);
        console2.log("Initial USDCm balance:", token0.balanceOf(swapper));
        console2.log("Initial USDTm balance:", token1.balanceOf(swapper));

        PoolKey memory key = createPoolKey();

        vm.startBroadcast(swapper);

        // Make the swap
        uint256 amountToSwap = 700e6; // 400 USDCm

        // Approve the router
        IERC20(Currency.unwrap(currency0)).approve(
            address(swapRouter),
            amountToSwap
        );

        // IERC20(Currency.unwrap(currency0)).approve(
        //     address(poolManager),
        //     type(uint256).max
        // ); // Approve PoolManager for USDCm //!No es necesario aprobar al PoolManager
        console2.log("Approved swapRouter to spend USDCm");

        // Swap settings
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });

        // Execute the swap
        console2.log("Executing swap of", amountToSwap, "USDCm for USDTm");
        console2.log("------ SWAPPER BALANCES BEFORE SWAP ------");
        console2.log("USDCm balance before swap:", token0.balanceOf(swapper));
        console2.log("USDTm balance before swap:", token1.balanceOf(swapper));
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -int256(amountToSwap),
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            settings,
            ZERO_BYTES
        );

        // Console logs to check swapper's balances after the swap
        console2.log("------ SWAPPER BALANCES AFTER SWAP ------");
        console2.log("USDCm balance after swap:", token0.balanceOf(swapper));
        console2.log("USDTm balance after swap:", token1.balanceOf(swapper));

        // Check the pool balances as well
        console2.log("------ POOL BALANCES AFTER SWAP ------");
        console2.log(
            "PoolManager balance of USDCm:",
            token0.balanceOf(address(poolManager))
        );
        console2.log(
            "PoolManager balance of USDTm:",
            token1.balanceOf(address(poolManager))
        );

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
