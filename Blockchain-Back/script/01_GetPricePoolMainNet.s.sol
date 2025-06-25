// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {console2} from "forge-std/console2.sol";

contract GetMainnetPrice is Script {
    // Direcciones **de Base mainnet**
    address constant POOL_MANAGER = 0x498581fF718922c3f8e6A244956aF099B2652b2b; //:contentReference[oaicite:0]{index=0}
    Currency constant USDC =
        Currency.wrap(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913); // mainnet
    Currency constant USDT =
        Currency.wrap(0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2); // mainnet

    function run() external view returns (uint160 sqrtPriceX96) {
        IPoolManager pm = IPoolManager(POOL_MANAGER);

        // PoolKey: (USDC, USDT, fee = 20, tickSpacing = 1, hooks = 0)
        PoolKey memory key = PoolKey({
            currency0: USDC < USDT ? USDC : USDT,
            currency1: USDC < USDT ? USDT : USDC,
            fee: 20,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });

        PoolId poolId = PoolId(key.toId());
        (sqrtPriceX96, , , ) = StateLibrary.getSlot0(pm, poolId);
        console2.log("sqrtPriceX96 mainnet:", sqrtPriceX96);
    }
}
