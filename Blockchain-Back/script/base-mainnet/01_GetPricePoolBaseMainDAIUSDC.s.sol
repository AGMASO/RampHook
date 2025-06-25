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
    address constant POOL_MANAGER = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    Currency constant USDT =
        Currency.wrap(0xdAC17F958D2ee523a2206206994597C13D831ec7); // mainnet beacuse no Dai/USDC
    Currency constant DAI =
        Currency.wrap(0x6B175474E89094C44Da98b954EedeAC495271d0F); // mainnet beacuse no Dai/USDC

    function run() external view returns (uint160 sqrtPriceX96) {
        IPoolManager pm = IPoolManager(POOL_MANAGER);

        PoolKey memory key = PoolKey({
            currency0: USDT < DAI ? USDT : DAI,
            currency1: USDT < DAI ? DAI : USDT,
            fee: 100,
            tickSpacing: 1,
            hooks: IHooks(address(0))
        });

        PoolId poolId = PoolId(key.toId());
        (sqrtPriceX96, , , ) = StateLibrary.getSlot0(pm, poolId);
        console2.log("sqrtPriceX96 mainnet:", sqrtPriceX96);
    }
}
