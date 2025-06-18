// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import "forge-std/Script.sol";
// import "forge-std/console.sol";
// import {IHooks} from "v4-core/interfaces/IHooks.sol";
// import {Hooks} from "v4-core/libraries/Hooks.sol";
// import {PoolManager} from "v4-core/PoolManager.sol";
// import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
// import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
// import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
// import {PoolDonateTest} from "v4-core/test/PoolDonateTest.sol";
// import {PoolKey} from "v4-core/types/PoolKey.sol";
// import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
// import {Constants} from "v4-core/../test/utils/Constants.sol";
// import {TickMath} from "v4-core/libraries/TickMath.sol";
// import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
// import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
// import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
// import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
// import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
// import {SortTokens} from "@uniswap/v4-core/test/utils/SortTokens.sol";
// import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
// import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";
// import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
// import {RampHookV1} from "../src/RampHookV1.sol";
// import {Vault} from "../src/Vault.sol";
// import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";

// import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

// import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

// import {RampHookV1} from "../src/RampHookV1.sol";
// import {Vault} from "../src/Vault.sol";

// contract RampHookV1Script is Script, Deployers {
//     address constant CREATE2_DEPLOYER =
//         address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
//     uint256 private pk = vm.envUint("PRIVATE_KEY");
//     address private _deployer = vm.addr(pk);

//     function setUp() public {}

//     function run() public {
//         vm.deal(_deployer, 100 ether);
//         vm.broadcast();
//         IPoolManager manager = deployPoolManager();

//         uint160 permissions = uint160(
//             Hooks.BEFORE_INITIALIZE_FLAG |
//                 Hooks.BEFORE_SWAP_FLAG |
//                 Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
//         );

//         vm.startBroadcast(_deployer);
//         Vault vault = new Vault();
//         (address hookAddress, bytes32 salt) = HookMiner.find(
//             CREATE2_DEPLOYER,
//             permissions,
//             type(RampHookV1).creationCode,
//             abi.encode(address(manager), address(vault))
//         );

//         RampHookV1 rampHook = new RampHookV1{salt: salt}(
//             manager,
//             address(vault)
//         );
//         require(
//             address(rampHook) == hookAddress,
//             "RampHook: hook address mismatch"
//         );
//         vm.stopBroadcast();
//         vm.startBroadcast();
//         (
//             PoolModifyLiquidityTest lpRouter,
//             PoolSwapTest swapRouter,

//         ) = deployRouters(manager);
//         vm.stopBroadcast();
//         console.log("Finishing setup...");
//         vm.startBroadcast();
//         testLifecycle(
//             manager,
//             address(rampHook),
//             address(vault),
//             lpRouter,
//             swapRouter
//         );
//         vm.stopBroadcast();
//     }

//     function deployPoolManager() internal returns (IPoolManager) {
//         return IPoolManager(address(new PoolManager(address(this))));
//     }

//     function deployRouters(
//         IPoolManager manager
//     )
//         internal
//         returns (
//             PoolModifyLiquidityTest lpRouter,
//             PoolSwapTest swapRouter,
//             PoolDonateTest donateRouter
//         )
//     {
//         lpRouter = new PoolModifyLiquidityTest(manager);
//         swapRouter = new PoolSwapTest(manager);
//         donateRouter = new PoolDonateTest(manager);
//     }

//     function deployTokens()
//         internal
//         returns (IERC20Minimal token0, IERC20Minimal token1)
//     {
//         MockERC20 tokenTest = new MockERC20("TEST", "TST", 18);
//         tokenTest.mint(msg.sender, 100_000 ether);
//         IERC20Minimal usdc = IERC20Minimal(
//             0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
//         );
//         deal(address(usdc), msg.sender, 100_000e6);
//         if (uint160(address(tokenTest)) < uint160(address(usdc))) {
//             token0 = tokenTest;
//             token1 = usdc;
//         } else {
//             token0 = usdc;
//             token1 = tokenTest;
//         }
//     }

//     function testLifecycle(
//         IPoolManager manager,
//         address rampHook,
//         address vault,
//         PoolModifyLiquidityTest lpRouter,
//         PoolSwapTest swapRouter
//     ) internal {
//         (IERC20Minimal token0, IERC20Minimal token1) = deployTokens();

//         address[5] memory toApprove = [
//             address(swapRouter),
//             address(lpRouter),
//             address(manager),
//             address(rampHook),
//             address(vault)
//         ];
//         for (uint256 i = 0; i < toApprove.length; i++) {
//             token0.approve(toApprove[i], type(uint256).max);
//         }
//         for (uint256 i = 0; i < toApprove.length; i++) {
//             token1.approve(toApprove[i], type(uint256).max);
//         }

//         (key, ) = initPool(
//             Currency.wrap(address(token0)),
//             Currency.wrap(address(token1)),
//             rampHook,
//             LPFeeLibrary.DYNAMIC_FEE_FLAG,
//             SQRT_PRICE_1_1
//         );

//         // (MockERC20 token0, MockERC20 token1) = deployTokens();
//         // token0.mint(msg.sender, 100_000 ether);
//         // token1.mint(msg.sender, 100_000 ether);

//         // bytes memory ZERO_BYTES = new bytes(0);

//         // int24 tickSpacing = 60;
//         // PoolKey memory poolKey = PoolKey(
//         //     Currency.wrap(address(token0)),
//         //     Currency.wrap(address(token1)),
//         //     3000,
//         //     tickSpacing,
//         //     IHooks(hook)
//         // );
//         // manager.initialize(poolKey, Constants.SQRT_PRICE_1_1, ZERO_BYTES);

//         // token0.approve(address(lpRouter), type(uint256).max);
//         // token1.approve(address(lpRouter), type(uint256).max);
//         // token0.approve(address(swapRouter), type(uint256).max);
//         // token1.approve(address(swapRouter), type(uint256).max);

//         // lpRouter.modifyLiquidity(
//         //     poolKey,
//         //     IPoolManager.ModifyLiquidityParams(
//         //         TickMath.minUsableTick(tickSpacing),
//         //         TickMath.maxUsableTick(tickSpacing),
//         //         100 ether,
//         //         0
//         //     ),
//         //     ZERO_BYTES
//         // );

//         console.log("Starting swap tests...");

//         //     for (uint256 i = 0; i < 6; i++) {
//         //         console.log("Attempting swap %d", i + 1);
//         //         try
//         //             swapRouter.swap(
//         //                 poolKey,
//         //                 IPoolManager.SwapParams({
//         //                     zeroForOne: true,
//         //                     amountSpecified: 1 ether,
//         //                     sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
//         //                 }),
//         //                 PoolSwapTest.TestSettings({
//         //                     takeClaims: false,
//         //                     settleUsingBurn: false
//         //                 }),
//         //                 new bytes(0)
//         //             )
//         //         {
//         //             console.log("Swap %d successful", i + 1);
//         //         } catch Error(string memory reason) {
//         //             console.log("Swap %d failed: %s", i + 1, reason);
//         //         } catch (bytes memory /*lowLevelData*/) {
//         //             console.log("Swap %d failed", i + 1);
//         //         }
//         //     }

//         //     console.log("Swap tests completed.");

//         //     SwapLimiterHook swapLimiter = SwapLimiterHook(hook);
//         //     uint256 remainingSwaps = swapLimiter.getRemainingSwaps(
//         //         address(swapRouter)
//         //     );
//         //     console.log("Remaining swaps for the sender: %d", remainingSwaps);
//         // }
//     }
// }
