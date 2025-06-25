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
    address private swapper = vm.addr(vm.envUint("PKSWAPPER_MAINNET"));
    // Hardcoded contract addresses (fill these in after deploying the main contracts)
    IPoolManager public constant poolManager =
        IPoolManager(0x498581fF718922c3f8e6A244956aF099B2652b2b); // Replace with actual address
    PoolSwapTest public constant swapRouter =
        PoolSwapTest(0xB49FC3B95c8B3134a0D7a59A970E7346A5d93436); // Replace with deployed address

    // Token addresses - using USDCm and USDTm
    IERC20 constant token0 = IERC20(0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb); // DAI
    IERC20 constant token1 = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913); // USDC

    Currency public currency0;
    Currency public currency1;
    // Pool key details - you'll need to update this with your deployed hook address
    bytes constant ZERO_BYTES = new bytes(0);
    int24 constant tickSpacing = 1;
    IHooks public constant hookContract =
        IHooks(0x1B13c5317565F4495133dBCE7eE82C65d2aa2088); // Replace with actual hook address

    function run() public {
        console2.log("Starting swap as account:", swapper);
        console2.log("Initial DAI balance:", token0.balanceOf(swapper));
        console2.log("Initial USDC balance:", token1.balanceOf(swapper));

        PoolKey memory key = createPoolKey();

        vm.startBroadcast(swapper);

        // Make the swap
        uint256 amountToSwap = 1e18; // 1 DAI

        // Approve the router
        IERC20(Currency.unwrap(currency0)).approve(
            address(swapRouter),
            amountToSwap
        );

        // IERC20(Currency.unwrap(currency0)).approve(
        //     address(poolManager),
        //     type(uint256).max
        // ); // Approve PoolManager for USDCm //!No es necesario aprobar al PoolManager
        console2.log("Approved swapRouter to spend DAI");

        // Swap settings
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });

        // Execute the swap
        console2.log("Executing swap of", amountToSwap, "DAI for USDC");
        console2.log("------ SWAPPER BALANCES BEFORE SWAP ------");
        console2.log("DAI balance before swap:", currency0.balanceOf(swapper));
        console2.log("USDC balance before swap:", currency1.balanceOf(swapper));
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
        console2.log("DAI balance after swap:", currency0.balanceOf(swapper));
        console2.log("USDC balance after swap:", currency1.balanceOf(swapper));

        // Check the pool balances as well
        console2.log("------ POOL BALANCES AFTER SWAP ------");
        console2.log(
            "PoolManager balance of DAI:",
            currency0.balanceOf(address(poolManager))
        );
        console2.log(
            "PoolManager balance of USDC:",
            currency1.balanceOf(address(poolManager))
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
