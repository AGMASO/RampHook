// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {console2} from "forge-std/console2.sol";

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

import {IUniswapV4Router04} from "hookmate/interfaces/router/IUniswapV4Router04.sol";
import {AddressConstants} from "hookmate/constants/AddressConstants.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {Vault} from "../src/Vault.sol";

import {RampHookV1} from "../src/RampHookV1.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";
import {LiquidityHelpers} from "./base/LiquidityHelpers.sol";

contract DeployAll is Script {
    IPermit2 immutable permit2 =
        IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IPoolManager public poolManager;
    IPositionManager public positionManager;
    PoolSwapTest public swapRouter =
        PoolSwapTest(0x311c8aBDE60097FFA5A9e404083A2D2A0eaeb4Cc);

    uint256 private pk = vm.envUint("PRIVATE_KEY");
    address private _deployer = vm.addr(pk);

    address private swapper = vm.addr(vm.envUint("PKSWAPPER"));

    IERC20 constant token0 = IERC20(0xEa54F59D3359B41fd5A86eaa0DC97Ab9e0F67634); // USDCm
    IERC20 constant token1 = IERC20(0x83fe3027f6550FFd97758d973B4242fe29e467f8); // USDTm

    int24 constant tickSpacing = 1;
    uint256 constant token0Amount = 1_000e6; // 1,000 USDC (6 decimals)
    uint256 constant token1Amount = 1_000e6; // 1,000 USDT (6 decimals)
    bytes constant ZERO_BYTES = new bytes(0);
    int24 tickLower;
    int24 tickUpper;
    PoolKey public key =
        PoolKey({
            currency0: Currency.wrap(address(token0)),
            currency1: Currency.wrap(address(token1)),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: tickSpacing,
            hooks: IHooks(0x83AEC9741734C6eb0535852cf637C3bfD5A5E088)
        });

    IHooks public hookContract;
    Vault public vault;
    RampHookV1 public ramphook;

    Currency public currency0;
    Currency public currency1;
    uint160 startingPrice = 79225444700572263652442542424; //price calculeted with extra script

    constructor() {}
    function run() public {
        poolManager = IPoolManager(
            AddressConstants.getPoolManagerAddress(block.chainid)
        );
        console2.log("PoolManager deployed at:", address(poolManager));
        positionManager = IPositionManager(
            payable(AddressConstants.getPositionManagerAddress(block.chainid))
        );
        console2.log("PositionManager deployed at:", address(positionManager));

        (currency0, currency1) = getCurrencies();
        console2.log(
            "Currency0:",
            Currency.unwrap(currency0),
            "Currency1:",
            Currency.unwrap(currency1)
        );
        vm.startBroadcast(_deployer);
        swapRouter = new PoolSwapTest(poolManager);
        console2.log(" SwapRouter deployed at:", address(swapRouter));
        deployHook();
        vm.stopBroadcast();
        vm.prank(CREATE2_FACTORY);
        ramphook.transferOwnership(_deployer);

        require(
            address(ramphook) == address(hookContract),
            "DeployHookScript: Hook Address Mismatch"
        );
        vm.label(Currency.unwrap(currency0), "Currency0");
        vm.label(Currency.unwrap(currency1), "Currency1");

        vm.label(address(poolManager), "PoolManager");
        vm.label(address(positionManager), "PositionManager");
        vm.label(address(swapRouter), "SwapRouter");
        vm.label(address(hookContract), "HookContract");

        vm.startBroadcast(_deployer);
        createPoolAndAddLiquidity();
        vm.stopBroadcast();

        //!DOnt Do swap
        vm.startBroadcast(_deployer);
        makeSwap();
        vm.stopBroadcast();
    }
    function getCurrencies() public pure returns (Currency, Currency) {
        require(address(token0) != address(token1));

        if (token0 < token1) {
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

    function deployHook() public {
        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
                Hooks.BEFORE_SWAP_FLAG |
                Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        vault = new Vault();
        console2.log(" Vault deployed at:", address(vault));

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(poolManager, address(vault));
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_FACTORY,
            flags,
            type(RampHookV1).creationCode,
            constructorArgs
        );
        hookContract = IHooks(hookAddress);

        // Deploy the hook using CREATE2

        ramphook = new RampHookV1{salt: salt}(poolManager, address(vault));
        console2.log("  RampHook deployed at:", address(ramphook));

        //TransferOwnership to the deployer
    }

    function createPoolAndAddLiquidity() public {
        uint256 price = (uint256(startingPrice) *
            uint256(startingPrice) *
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
        // console2.log("PoolKey created with currencies:", poolKey.currency0);
        // console2.log("PoolKey created with currencies:", poolKey.currency1);
        // console2.log("PoolKey fee:", poolKey.fee);
        // console2.log("PoolKey tickSpacing:", poolKey.tickSpacing);
        // console2.log("PoolKey hooks:", address(poolKey.hooks));
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

        tokenApprovals();

        console2.log(address(_deployer).balance);
        console2.log(currency1.balanceOf(_deployer));
        //! Multicall to atomically create pool & add liquidity
        positionManager.multicall{value: valueToPass}(params);

        console2.log("Pool created and liquidity added successfully");
        bytes32 poolId = PoolId.unwrap(poolKey.toId());
        key = poolKey;
        console2.log("Pool ID:", vm.toString(poolId));
        console2.log(
            "PoolManager balance of currency0:",
            IERC20(Currency.unwrap(currency0)).balanceOf(address(poolManager))
        );
        console2.log(
            "PoolManager balance of currency1:",
            IERC20(Currency.unwrap(currency1)).balanceOf(address(poolManager))
        );
    }

    function makeSwap() public {
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });

        IERC20(Currency.unwrap(currency0)).approve(address(swapRouter), 400e6);

        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -400e6,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            settings,
            ZERO_BYTES
        );

        // Console logs to check swapper's balances after the swap
        console2.log("------ SWAPPER BALANCES AFTER SWAP ------");
        console2.log("Swapper address:", swapper);
        console2.log(
            "USDCm balance after swap:",
            IERC20(Currency.unwrap(currency0)).balanceOf(swapper)
        );
        console2.log(
            "USDTm balance after swap:",
            IERC20(Currency.unwrap(currency1)).balanceOf(swapper)
        );

        // Check the pool balances as well
        console2.log("------ POOL BALANCES AFTER SWAP ------");
        console2.log(
            "PoolManager balance of currency0:",
            IERC20(Currency.unwrap(currency0)).balanceOf(address(poolManager))
        );
        console2.log(
            "PoolManager balance of currency1:",
            IERC20(Currency.unwrap(currency1)).balanceOf(address(poolManager))
        );
    }

    function _mintLiquidityParams(
        PoolKey memory poolKey,
        int24 _tickLower,
        int24 _tickUpper,
        uint256 liquidity,
        uint256 amount0Max,
        uint256 amount1Max,
        address recipient,
        bytes memory hookData
    ) internal pure returns (bytes memory, bytes[] memory) {
        bytes memory actions = abi.encodePacked(
            uint8(Actions.MINT_POSITION),
            uint8(Actions.SETTLE_PAIR),
            uint8(Actions.SWEEP),
            uint8(Actions.SWEEP)
        );

        bytes[] memory params = new bytes[](4);
        params[0] = abi.encode(
            poolKey,
            _tickLower,
            _tickUpper,
            liquidity,
            amount0Max,
            amount1Max,
            recipient,
            hookData
        );
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);
        params[2] = abi.encode(poolKey.currency0, recipient);
        params[3] = abi.encode(poolKey.currency1, recipient);

        return (actions, params);
    }
    function tokenApprovals() public {
        if (!currency0.isAddressZero()) {
            IERC20(Currency.unwrap(currency0)).approve(
                address(permit2),
                type(uint256).max
            );
            permit2.approve(
                Currency.unwrap(currency0),
                address(positionManager),
                type(uint160).max,
                type(uint48).max
            );
        }

        if (!currency1.isAddressZero()) {
            IERC20(Currency.unwrap(currency1)).approve(
                address(permit2),
                type(uint256).max
            );
            permit2.approve(
                Currency.unwrap(currency1),
                address(positionManager),
                type(uint160).max,
                type(uint48).max
            );
        }
    }
}
