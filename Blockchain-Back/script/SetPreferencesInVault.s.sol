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

contract SetPreferencesInVaultScript is Script {
    address private _deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
    // Hardcoded contract addresses (fill these in after deploying the main contracts)
    IPoolManager public constant poolManager =
        IPoolManager(0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408);
    PoolSwapTest public constant swapRouter =
        PoolSwapTest(0x5e688a383919dF58EF5840721B2eb5105071BF7E);
    Vault public constant vault =
        Vault(0x4A360497111D4888f79d7CFeC697562611b7F62f);
    // Token addresses - using USDCm and USDTm
    IERC20 constant token0 = IERC20(0xB9a9553E08e5AFc8a7E16613572CC8F96B3143F9); // USDCm
    IERC20 constant token1 = IERC20(0xDFB44df01A97Ff7Fd0Df16872193ceCB3A8C1ac3); // USDTm

    Currency public currency0;
    Currency public currency1;
    // Pool key details - you'll need to update this with your deployed hook address
    bytes constant ZERO_BYTES = new bytes(0);
    int24 constant tickSpacing = 1;
    IHooks public constant hookContract =
        IHooks(0xA11444D0C7085ce34D8CCcEd3fe543B658246088); // Replace with actual hook address

    function run() public {
        PoolKey memory key = createPoolKey();

        vm.startBroadcast(_deployer);

        vault.setWhiteListRampHook(key);
        console2.log(
            "RampHook address: %s",
            vault.rampHooks(PoolId.unwrap(key.toId()))
        );
        vm.stopBroadcast();

        vm.startBroadcast(_deployer);
        vault.setPoolKey(
            Currency.unwrap(currency0),
            Currency.unwrap(currency1),
            key
        );
        vm.stopBroadcast();

        assert(
            vault.rampHooks(PoolId.unwrap(key.toId())) == address(hookContract)
        );
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
