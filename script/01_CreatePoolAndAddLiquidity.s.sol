// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console2} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {BaseScript} from "./base/BaseScript.sol";
import {LiquidityHelpers} from "./base/LiquidityHelpers.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";

contract CreatePoolAndAddLiquidityScript is BaseScript, LiquidityHelpers {
    using CurrencyLibrary for Currency;
    uint256 private pk = vm.envUint("PRIVATE_KEY");
    address private _deployer = vm.addr(pk);
    /////////////////////////////////////
    // --- Configure These ---
    /////////////////////////////////////

    uint24 lpFee = 50;
    int24 tickSpacing = 1;
    uint160 startingPrice; // Starting price, sqrtPriceX96; floor(sqrt(1) * 2^96)

    // --- liquidity position configuration --- //
    uint256 public token0Amount = 1_000e6; // 1,000 USDC (6 decimals)
    uint256 public token1Amount = 1_000e6; // 1,000 USDT (6 decimals)

    // range of the position, must be a multiple of tickSpacing
    int24 tickLower;
    int24 tickUpper;
    /////////////////////////////////////

    function run() external {
        vm.deal(_deployer, 10 ether);

        address whaleUsdc = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
        IERC20 usdc = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);

        // Impersona whale para transferir tokens al deployer
        vm.startPrank(whaleUsdc);
        usdc.transfer(_deployer, 1_000_000e6);
        vm.stopPrank();

        // Desde el deployer, aprueba a PoolManager
        vm.prank(_deployer);
        usdc.approve(address(poolManager), type(uint256).max);

        // Verifica que allowance ahora sí existe
        console2.log("Balance USDC:", usdc.balanceOf(_deployer));
        console2.log(
            "Allowance to PoolManager:",
            usdc.allowance(_deployer, address(poolManager))
        );

        address whaleUsdT = 0xeE7981C4642dE8d19AeD11dA3bac59277DfD59D7; // impersonas al whale
        IERC20 usdt = IERC20(0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2);

        vm.startPrank(whaleUsdT); // impersonas al whale
        usdt.transfer(_deployer, 1_000_000e6); // te envías 1 M de USDC (6 decimales)
        vm.stopPrank();

        vm.prank(_deployer);
        usdt.approve(address(poolManager), type(uint256).max); // approve PoolManager to spend USDT

        console2.log("Balance USDT:", usdt.balanceOf(_deployer));
        console2.log(
            "Allowance to PoolManager:",
            usdt.allowance(_deployer, address(poolManager))
        );
        (
            uint160 sqrtPriceX96WethUsdc,
            int24 tickCurrentWethUsdc
        ) = getSlot0OfficialPoolWethUsdc(
                currency0,
                currency1,
                20,
                1,
                IHooks(address(0))
            );

        startingPrice = sqrtPriceX96WethUsdc;
        uint256 price = (uint256(sqrtPriceX96WethUsdc) *
            uint256(sqrtPriceX96WethUsdc) *
            1e18) >> 192;
        console2.log("Starting sqrtPrice:", startingPrice);
        console2.log("Starting price:", price / 1e12);
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: tickSpacing,
            hooks: hookContract
        });

        bytes memory hookData = new bytes(0);

        int24 currentTick = TickMath.getTickAtSqrtPrice(startingPrice);

        tickLower =
            ((currentTick - 750 * tickSpacing) / tickSpacing) *
            tickSpacing;
        tickUpper =
            ((currentTick + 750 * tickSpacing) / tickSpacing) *
            tickSpacing;

        // Converts token amounts to liquidity units
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            startingPrice,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            token0Amount,
            token1Amount
        );

        // slippage limits
        uint256 amount0Max = token0Amount + 1;
        uint256 amount1Max = token1Amount + 1;

        (
            bytes memory actions,
            bytes[] memory mintParams
        ) = _mintLiquidityParams(
                poolKey,
                tickLower,
                tickUpper,
                liquidity,
                amount0Max,
                amount1Max,
                _deployer,
                hookData
            );

        // multicall parameters
        bytes[] memory params = new bytes[](2);

        // Initialize Pool
        console2.log(startingPrice);
        params[0] = abi.encodeWithSelector(
            positionManager.initializePool.selector,
            poolKey,
            startingPrice,
            hookData
        );

        // Mint Liquidity
        params[1] = abi.encodeWithSelector(
            positionManager.modifyLiquidities.selector,
            abi.encode(actions, mintParams),
            block.timestamp + 3600
        );

        // If the pool is an ETH pair, native tokens are to be transferred
        uint256 valueToPass = currency0.isAddressZero() ? amount0Max : 0;

        vm.startBroadcast();
        tokenApprovals();

        console2.log(address(_deployer).balance);
        console2.log(currency1.balanceOf(_deployer));
        // Multicall to atomically create pool & add liquidity
        positionManager.multicall{value: valueToPass}(params);
        vm.stopBroadcast();
    }

    // }
    // // currency0: currency0,
    // // currency1: currency1,
    // // fee: lpFee,
    // // tickSpacing: tickSpacing,
    // // hooks: hookContract
    function getSlot0OfficialPoolWethUsdc(
        Currency _currency0,
        Currency _currency1,
        uint24 _fee,
        int24 _tickSpacing,
        IHooks _hookContract
    ) public view returns (uint160, int24) {
        PoolKey memory referenceKey = PoolKey({
            currency0: _currency0,
            currency1: _currency1,
            fee: _fee,
            tickSpacing: _tickSpacing,
            hooks: _hookContract
        });

        PoolId poolId = PoolId(referenceKey.toId());
        (uint160 sqrtPriceX96, int24 tick, , ) = StateLibrary.getSlot0(
            poolManager,
            poolId
        );
        assert(sqrtPriceX96 > 0);

        return (sqrtPriceX96, tick);
    }
}
