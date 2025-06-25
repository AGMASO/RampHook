// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {SortTokens} from "@uniswap/v4-core/test/utils/SortTokens.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {RampHookV1} from "../src/RampHookV1.sol";
import {Vault} from "../src/Vault.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";

import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";

contract RampHookTest is Test, Deployers {
    using PoolIdLibrary for PoolId;
    using CurrencyLibrary for Currency;

    RampHookV1 hook;
    Vault vault;
    address public USER = makeAddr("USER");
    address public USER2 = makeAddr("USER2");
    PoolKey s_key;

    function setUp() public {
        vault = new Vault();

        deployFreshManagerAndRouters();

        MockERC20 _currencyA = new MockERC20("FakeUsdc", "USDC", 6);
        address usdcTokenAddressBase = 0xC20f3Fe19A33572D68Bcb835504862966C022260;
        vm.etch(usdcTokenAddressBase, address(_currencyA).code);
        _currencyA = MockERC20(usdcTokenAddressBase);
        _currencyA.mint(address(this), 1_000_000_000_000_000_000_000e6); // type(uint256).max);
        address[9] memory toApprove = [
            address(swapRouter),
            address(swapRouterNoChecks),
            address(modifyLiquidityRouter),
            address(modifyLiquidityNoChecks),
            address(donateRouter),
            address(takeRouter),
            address(claimsRouter),
            address(nestedActionRouter.executor()),
            address(actionsRouter)
        ];
        for (uint256 i = 0; i < toApprove.length; i++) {
            _currencyA.approve(toApprove[i], type(uint256).max);
        }
        Currency _currencyB = deployMintAndApproveCurrency();

        (currency0, currency1) = SortTokens.sort(
            MockERC20(_currencyA),
            MockERC20(Currency.unwrap(_currencyB))
        );
        console2.log(
            "currency0: %s, currency1: %s",
            Currency.unwrap(currency0),
            Currency.unwrap(currency1)
        );
        console2.log(currency0.balanceOf(address(this)));
        console2.log(currency1.balanceOf(address(this)));

        address hookAddress = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG |
                    Hooks.BEFORE_SWAP_FLAG |
                    Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            )
        );
        deployCodeTo(
            "RampHookV1.sol",
            abi.encode(manager, address(vault)),
            hookAddress
        );
        hook = RampHookV1(hookAddress);

        (key, ) = initPool(
            currency0,
            currency1,
            hook,
            LPFeeLibrary.DYNAMIC_FEE_FLAG,
            SQRT_PRICE_1_1
        );
        s_key = key;
        // Add some initial liquidity through the custom `addLiquidity` function
        IERC20Minimal(Currency.unwrap(key.currency0)).approve(
            hookAddress,
            1000 ether
        );
        IERC20Minimal(Currency.unwrap(key.currency1)).approve(
            hookAddress,
            1000 ether
        );
        // modifyLiquidityRouter.modifyLiquidity(
        //     key,
        //     ModifyLiquidityParams({
        //         tickLower: -60,
        //         tickUpper: 60,
        //         liquidityDelta: 10 ether,
        //         salt: bytes32(0)
        //     }),
        //     ZERO_BYTES
        // );
        // // Some liquidity from -120 to +120 tick range
        // modifyLiquidityRouter.modifyLiquidity(
        //     key,
        //     ModifyLiquidityParams({
        //         tickLower: -120,
        //         tickUpper: 120,
        //         liquidityDelta: 10 ether,
        //         salt: bytes32(0)
        //     }),
        //     ZERO_BYTES
        // );
        // some liquidity for full range
        modifyLiquidityRouter.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: TickMath.minUsableTick(60),
                tickUpper: TickMath.maxUsableTick(60),
                liquidityDelta: 60000 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );

        //Vault setup
        vault.setWhiteListRampHook(key);
        console2.log(
            "RampHook address: %s",
            vault.rampHooks(PoolId.unwrap(key.toId()))
        );
        vault.setPoolKey(
            Currency.unwrap(currency0),
            Currency.unwrap(currency1),
            key
        );
        assert(vault.rampHooks(PoolId.unwrap(key.toId())) == address(hook));
        // assert(
        //     vault.poolKeysByTokenPair(
        //         Currency.unwrap(currency0),
        //         Currency.unwrap(currency1)
        //     ) == key
        // );

        vm.prank(address(vault));
        IERC20Minimal(Currency.unwrap(key.currency0)).approve(
            address(hook),
            type(uint256).max
        );
        vm.prank(address(vault));
        IERC20Minimal(Currency.unwrap(key.currency1)).approve(
            address(hook),
            type(uint256).max
        );
    }

    function test_onRampMatchedOrders() public {
        deal(Currency.unwrap(s_key.currency1), USER, 3000 ether);
        vm.prank(USER);
        s_key.currency1.transfer(address(vault), 3000 ether);
        console2.log(
            "Vault currency0 balance before onramp: %s",
            s_key.currency0.balanceOf(address(vault))
        );
        console2.log(
            "Vault currency1 balance before onramp: %s",
            s_key.currency1.balanceOf(address(vault))
        );
        console2.log(
            "PM currency0 balance before onramp: %s",
            s_key.currency0.balanceOf(address(manager))
        );
        console2.log(
            "PM currency1 balance before onramp: %s",
            s_key.currency1.balanceOf(address(manager))
        );

        // struct OnrampData {
        //     uint256 amount;
        //     address receiverAddress;
        //     address desiredToken;
        // }

        Vault.OnrampData memory onRampData = Vault.OnrampData({
            amount: 200e18, // 200 USDC
            receiverAddress: USER,
            desiredToken: Currency.unwrap(s_key.currency0)
        });

        vault.onramp(onRampData);
        vm.stopPrank();
        console2.log(
            "Hook currency0 balance after onramp: %s",
            s_key.currency0.balanceOf(address(hook))
        );
        console2.log(
            "Hook currency1 balance after onramp: %s",
            s_key.currency1.balanceOf(address(hook))
        );
        console2.log(
            "Vault currency0 balance after onramp: %s",
            s_key.currency0.balanceOf(address(vault))
        );
        console2.log(
            "Vault currency1 balance after onramp: %s",
            s_key.currency1.balanceOf(address(vault))
        );
        console2.log(
            "PM currency0 balance after onramp: %s",
            s_key.currency0.balanceOf(address(manager))
        );
        console2.log(
            "PM currency1 balance after onramp: %s",
            s_key.currency1.balanceOf(address(manager))
        );
        console2.log(
            "HOOK Claims0 balance after onramp: %s",
            manager.balanceOf(address(hook), s_key.currency0.toId())
        );
        console2.log(
            "HOOK Claims1 balance after onramp: %s",
            manager.balanceOf(address(hook), s_key.currency1.toId())
        );

        // mapping(PoolId poolId => mapping(bool zeroForOne => OnRampOrder[]))
        // public pendingOrders;
        RampHookV1.OnRampOrder[] memory pendingOrders = hook.getPendingOrders(
            s_key.toId(),
            false
        );
        assertEq(pendingOrders.length, 1, "Pending orders length should be 1");

        /// Enviar un Swap desde otro User para matchear el pedido
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });
        vm.startPrank(USER2);
        deal(Currency.unwrap(s_key.currency0), USER2, 200e18);
        IERC20Minimal(Currency.unwrap(s_key.currency0)).approve(
            address(swapRouter),
            400e18
        );
        console2.log(
            "USER2 balance before swap matched: %s",
            s_key.currency0.balanceOf(USER2)
        );
        console2.log(
            "USER2 balance before swap matched: %s",
            s_key.currency1.balanceOf(USER2)
        );
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -200e18,
                sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
            }),
            settings,
            ZERO_BYTES
        );

        console2.log(
            "Hook currency0 balance after swap matched: %s",
            s_key.currency0.balanceOf(address(hook))
        );
        console2.log(
            "Hook currency1 balance after swap matched: %s",
            s_key.currency1.balanceOf(address(hook))
        );
        console2.log(
            "Vault currency0 balance after swap matched: %s",
            s_key.currency0.balanceOf(address(vault))
        );
        console2.log(
            "Vault currency1 balance after swap matched: %s",
            s_key.currency1.balanceOf(address(vault))
        );
        console2.log(
            "PM currency0 balance after swap matched: %s",
            s_key.currency0.balanceOf(address(manager))
        );
        console2.log(
            "PM currency1 balance after swap matched: %s",
            s_key.currency1.balanceOf(address(manager))
        );
        console2.log(
            "HOOK Claims0 balance after swap matched: %s",
            manager.balanceOf(address(hook), s_key.currency0.toId())
        );
        console2.log(
            "HOOK Claims1 balance after swap matched: %s",
            manager.balanceOf(address(hook), s_key.currency1.toId())
        );

        console2.log(
            "USER1 balance after swap matched: %s",
            s_key.currency0.balanceOf(USER)
        );
        console2.log(
            "USER1 balance after swap matched: %s",
            s_key.currency1.balanceOf(USER)
        );
        console2.log(
            "USER2 balance after swap matched: %s",
            s_key.currency0.balanceOf(USER2)
        );
        console2.log(
            "USER2 balance after swap matched: %s",
            s_key.currency1.balanceOf(USER2)
        );
        console2.log(
            "Hook balance of TOken0 after swap matched: %s",
            s_key.currency0.balanceOf(address(hook))
        );
        console2.log(
            "Hook balance of TOken1 after swap matched: %s",
            s_key.currency1.balanceOf(address(hook))
        );
        vm.stopPrank();
    }

    function test_onRampNoMatchNormalSwap() public {
        deal(Currency.unwrap(s_key.currency1), USER, 3000 ether);
        vm.prank(USER);
        s_key.currency1.transfer(address(vault), 3000 ether);
        console2.log(
            "Vault currency0 balance before onramp: %s",
            s_key.currency0.balanceOf(address(vault))
        );
        console2.log(
            "Vault currency1 balance before onramp: %s",
            s_key.currency1.balanceOf(address(vault))
        );
        console2.log(
            "PM currency0 balance before onramp: %s",
            s_key.currency0.balanceOf(address(manager))
        );
        console2.log(
            "PM currency1 balance before onramp: %s",
            s_key.currency1.balanceOf(address(manager))
        );

        Vault.OnrampData memory onRampData = Vault.OnrampData({
            amount: 200e18, // 200 USDC
            receiverAddress: USER,
            desiredToken: Currency.unwrap(s_key.currency0)
        });

        vault.onramp(onRampData);
        vm.stopPrank();
        console2.log(
            "Hook currency0 balance after onramp: %s",
            s_key.currency0.balanceOf(address(hook))
        );
        console2.log(
            "Hook currency1 balance after onramp: %s",
            s_key.currency1.balanceOf(address(hook))
        );
        console2.log(
            "Vault currency0 balance after onramp: %s",
            s_key.currency0.balanceOf(address(vault))
        );
        console2.log(
            "Vault currency1 balance after onramp: %s",
            s_key.currency1.balanceOf(address(vault))
        );
        console2.log(
            "PM currency0 balance after onramp: %s",
            s_key.currency0.balanceOf(address(manager))
        );
        console2.log(
            "PM currency1 balance after onramp: %s",
            s_key.currency1.balanceOf(address(manager))
        );
        console2.log(
            "HOOK Claims0 balance after onramp: %s",
            manager.balanceOf(address(hook), s_key.currency0.toId())
        );
        console2.log(
            "HOOK Claims1 balance after onramp: %s",
            manager.balanceOf(address(hook), s_key.currency1.toId())
        );

        RampHookV1.OnRampOrder[] memory pendingOrders = hook.getPendingOrders(
            s_key.toId(),
            false
        );
        assertEq(pendingOrders.length, 1, "Pending orders length should be 1");

        // Enviar un Swap desde otro User para matchear el pedido
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });
        vm.startPrank(USER2);
        deal(Currency.unwrap(s_key.currency0), USER2, 400e18);
        deal(Currency.unwrap(s_key.currency1), USER2, 400e18);

        IERC20Minimal(Currency.unwrap(s_key.currency0)).approve(
            address(swapRouter),
            400e18
        );
        IERC20Minimal(Currency.unwrap(s_key.currency1)).approve(
            address(swapRouter),
            400e18
        );
        console2.log(
            "USER2 balance currency0 before swap not matched: %s",
            s_key.currency0.balanceOf(USER2)
        );
        console2.log(
            "USER2 balance currency1 before swap not matched: %s",
            s_key.currency1.balanceOf(USER2)
        );
        (uint160 sqrtPriceX96, int24 tick, , ) = StateLibrary.getSlot0(
            manager,
            s_key.toId()
        );
        uint256 actualPriceOfPool = hook._tickToPrice(tick);
        console2.log("Sqrt price before swap: %s", sqrtPriceX96);
        console2.log("Tick before swap: %s", tick);
        //!cambia de zeroForOne como el precio baja, entocnes MIN_SQRT_PRICE + 1.
        //! Como es menor de cualqueir Orden de OnRamp, hacemos todo en Pool

        // swapRouter.swap(
        //     key,
        //     SwapParams({
        //         zeroForOne: true,
        //         amountSpecified: -100e18,
        //         sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        //     }),
        //     settings,
        //     ZERO_BYTES
        // );
        //!lo mismo pero para probar cuando no hay match opositor.
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: false,
                amountSpecified: -100e18,
                sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1
            }),
            settings,
            ZERO_BYTES
        );
        uint256 hookBalanceAfterToken0 = s_key.currency0.balanceOf(
            address(hook)
        );
        console2.log(
            "Hook balance after token0 swap: %s",
            hookBalanceAfterToken0
        );
        uint256 hookBalanceAfterToken1 = s_key.currency1.balanceOf(
            address(hook)
        );
        console2.log(
            "Hook currency0 balance after swap matched: %s",
            s_key.currency0.balanceOf(address(hook))
        );
        console2.log(
            "Hook currency1 balance after swap matched: %s",
            s_key.currency1.balanceOf(address(hook))
        );
        console2.log(
            "Vault currency0 balance after swap matched: %s",
            s_key.currency0.balanceOf(address(vault))
        );
        console2.log(
            "Vault currency1 balance after swap matched: %s",
            s_key.currency1.balanceOf(address(vault))
        );
        console2.log(
            "PM currency0 balance after swap matched: %s",
            s_key.currency0.balanceOf(address(manager))
        );
        console2.log(
            "PM currency1 balance after swap matched: %s",
            s_key.currency1.balanceOf(address(manager))
        );
        console2.log(
            "HOOK Claims0 balance after swap matched: %s",
            manager.balanceOf(address(hook), s_key.currency0.toId())
        );
        console2.log(
            "HOOK Claims1 balance after swap matched: %s",
            manager.balanceOf(address(hook), s_key.currency1.toId())
        );

        console2.log(
            "USER1 balance after swap matched: %s",
            s_key.currency0.balanceOf(USER)
        );
        console2.log(
            "USER1 balance after swap matched: %s",
            s_key.currency1.balanceOf(USER)
        );
        console2.log(
            "USER2 balance after swap matched: %s",
            s_key.currency0.balanceOf(USER2)
        );
        console2.log(
            "USER2 balance after swap matched: %s",
            s_key.currency1.balanceOf(USER2)
        );
        console2.log(
            "Hook balance of TOken0 after swap matched: %s",
            s_key.currency0.balanceOf(address(hook))
        );
        console2.log(
            "Hook balance of TOken1 after swap matched: %s",
            s_key.currency1.balanceOf(address(hook))
        );
        vm.stopPrank();
    }

    function test_swapperOrderGreaterThanOnrampOrder() public {
        deal(Currency.unwrap(s_key.currency1), USER, 3000 ether);
        vm.prank(USER);
        s_key.currency1.transfer(address(vault), 3000 ether);
        console2.log(
            "Vault currency0 balance before onramp: %s",
            s_key.currency0.balanceOf(address(vault))
        );
        console2.log(
            "Vault currency1 balance before onramp: %s",
            s_key.currency1.balanceOf(address(vault))
        );
        console2.log(
            "PM currency0 balance before onramp: %s",
            s_key.currency0.balanceOf(address(manager))
        );
        console2.log(
            "PM currency1 balance before onramp: %s",
            s_key.currency1.balanceOf(address(manager))
        );

        Vault.OnrampData memory onRampData = Vault.OnrampData({
            amount: 200e18, // 200 USDC
            receiverAddress: USER,
            desiredToken: Currency.unwrap(s_key.currency0)
        });

        vault.onramp(onRampData);
        vm.stopPrank();
        console2.log(
            "Hook currency0 balance after onramp: %s",
            s_key.currency0.balanceOf(address(hook))
        );
        console2.log(
            "Hook currency1 balance after onramp: %s",
            s_key.currency1.balanceOf(address(hook))
        );
        console2.log(
            "Vault currency0 balance after onramp: %s",
            s_key.currency0.balanceOf(address(vault))
        );
        console2.log(
            "Vault currency1 balance after onramp: %s",
            s_key.currency1.balanceOf(address(vault))
        );
        console2.log(
            "PM currency0 balance after onramp: %s",
            s_key.currency0.balanceOf(address(manager))
        );
        console2.log(
            "PM currency1 balance after onramp: %s",
            s_key.currency1.balanceOf(address(manager))
        );
        console2.log(
            "HOOK Claims0 balance after onramp: %s",
            manager.balanceOf(address(hook), s_key.currency0.toId())
        );
        console2.log(
            "HOOK Claims1 balance after onramp: %s",
            manager.balanceOf(address(hook), s_key.currency1.toId())
        );

        RampHookV1.OnRampOrder[] memory pendingOrders = hook.getPendingOrders(
            s_key.toId(),
            false
        );
        assertEq(pendingOrders.length, 1, "Pending orders length should be 1");

        // Enviar un Swap desde otro User para matchear el pedido
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });
        vm.startPrank(USER2);
        deal(Currency.unwrap(s_key.currency0), USER2, 400e18);
        deal(Currency.unwrap(s_key.currency1), USER2, 400e18);

        IERC20Minimal(Currency.unwrap(s_key.currency0)).approve(
            address(swapRouter),
            400e18
        );
        IERC20Minimal(Currency.unwrap(s_key.currency1)).approve(
            address(swapRouter),
            400e18
        );
        console2.log(
            "USER2 balance currency0 before swap not matched: %s",
            s_key.currency0.balanceOf(USER2)
        );
        console2.log(
            "USER2 balance currency1 before swap not matched: %s",
            s_key.currency1.balanceOf(USER2)
        );
        (uint160 sqrtPriceX96, int24 tick, , ) = StateLibrary.getSlot0(
            manager,
            s_key.toId()
        );
        uint256 actualPriceOfPool = hook._tickToPrice(tick);
        console2.log("Sqrt price before swap: %s", sqrtPriceX96);
        console2.log("Tick before swap: %s", tick);
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -300e18,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            settings,
            ZERO_BYTES
        );
        uint256 hookBalanceAfterToken0 = s_key.currency0.balanceOf(
            address(hook)
        );
        console2.log(
            "Hook balance after token0 swap: %s",
            hookBalanceAfterToken0
        );
        uint256 hookBalanceAfterToken1 = s_key.currency1.balanceOf(
            address(hook)
        );
        console2.log(
            "Hook currency0 balance after swap matched: %s",
            s_key.currency0.balanceOf(address(hook))
        );
        console2.log(
            "Hook currency1 balance after swap matched: %s",
            s_key.currency1.balanceOf(address(hook))
        );
        console2.log(
            "Vault currency0 balance after swap matched: %s",
            s_key.currency0.balanceOf(address(vault))
        );
        console2.log(
            "Vault currency1 balance after swap matched: %s",
            s_key.currency1.balanceOf(address(vault))
        );
        console2.log(
            "PM currency0 balance after swap matched: %s",
            s_key.currency0.balanceOf(address(manager))
        );
        console2.log(
            "PM currency1 balance after swap matched: %s",
            s_key.currency1.balanceOf(address(manager))
        );
        console2.log(
            "HOOK Claims0 balance after swap matched: %s",
            manager.balanceOf(address(hook), s_key.currency0.toId())
        );
        console2.log(
            "HOOK Claims1 balance after swap matched: %s",
            manager.balanceOf(address(hook), s_key.currency1.toId())
        );

        console2.log(
            "USER1 balance after swap matched: %s",
            s_key.currency0.balanceOf(USER)
        );
        console2.log(
            "USER1 balance after swap matched: %s",
            s_key.currency1.balanceOf(USER)
        );
        console2.log(
            "USER2 balance after swap matched: %s",
            s_key.currency0.balanceOf(USER2)
        );
        console2.log(
            "USER2 balance after swap matched: %s",
            s_key.currency1.balanceOf(USER2)
        );
        console2.log(
            "Hook balance of TOken0 after swap matched: %s",
            s_key.currency0.balanceOf(address(hook))
        );
        console2.log(
            "Hook balance of TOken1 after swap matched: %s",
            s_key.currency1.balanceOf(address(hook))
        );
        vm.stopPrank();
    }
    function test_swapperPerformManyOrdersOnRamp() public {
        deal(Currency.unwrap(s_key.currency1), USER, 3000 ether);
        vm.prank(USER);
        s_key.currency1.transfer(address(vault), 3000 ether);
        console2.log(
            "Vault currency0 balance before onramp: %s",
            s_key.currency0.balanceOf(address(vault))
        );
        console2.log(
            "Vault currency1 balance before onramp: %s",
            s_key.currency1.balanceOf(address(vault))
        );
        console2.log(
            "PM currency0 balance before onramp: %s",
            s_key.currency0.balanceOf(address(manager))
        );
        console2.log(
            "PM currency1 balance before onramp: %s",
            s_key.currency1.balanceOf(address(manager))
        );

        Vault.OnrampData memory onRampData = Vault.OnrampData({
            amount: 200e18, // 200 USDC
            receiverAddress: USER,
            desiredToken: Currency.unwrap(s_key.currency0)
        });

        vault.onramp(onRampData);
        vault.onramp(onRampData);

        vm.stopPrank();
        console2.log(
            "Hook currency0 balance after onramp: %s",
            s_key.currency0.balanceOf(address(hook))
        );
        console2.log(
            "Hook currency1 balance after onramp: %s",
            s_key.currency1.balanceOf(address(hook))
        );
        console2.log(
            "Vault currency0 balance after onramp: %s",
            s_key.currency0.balanceOf(address(vault))
        );
        console2.log(
            "Vault currency1 balance after onramp: %s",
            s_key.currency1.balanceOf(address(vault))
        );
        console2.log(
            "PM currency0 balance after onramp: %s",
            s_key.currency0.balanceOf(address(manager))
        );
        console2.log(
            "PM currency1 balance after onramp: %s",
            s_key.currency1.balanceOf(address(manager))
        );
        console2.log(
            "HOOK Claims0 balance after onramp: %s",
            manager.balanceOf(address(hook), s_key.currency0.toId())
        );
        console2.log(
            "HOOK Claims1 balance after onramp: %s",
            manager.balanceOf(address(hook), s_key.currency1.toId())
        );

        RampHookV1.OnRampOrder[] memory pendingOrders = hook.getPendingOrders(
            s_key.toId(),
            false
        );
        assertEq(pendingOrders.length, 2, "Pending orders length should be 1");

        // Enviar un Swap desde otro User para matchear el pedido
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });
        vm.startPrank(USER2);
        deal(Currency.unwrap(s_key.currency0), USER2, 600e18);
        deal(Currency.unwrap(s_key.currency1), USER2, 600e18);

        IERC20Minimal(Currency.unwrap(s_key.currency0)).approve(
            address(swapRouter),
            600e18
        );
        IERC20Minimal(Currency.unwrap(s_key.currency1)).approve(
            address(swapRouter),
            600e18
        );
        console2.log(
            "USER2 balance currency0 before swap not matched: %s",
            s_key.currency0.balanceOf(USER2)
        );
        console2.log(
            "USER2 balance currency1 before swap not matched: %s",
            s_key.currency1.balanceOf(USER2)
        );
        (uint160 sqrtPriceX96, int24 tick, , ) = StateLibrary.getSlot0(
            manager,
            s_key.toId()
        );
        uint256 actualPriceOfPool = hook._tickToPrice(tick);
        console2.log("Sqrt price before swap: %s", sqrtPriceX96);
        console2.log("Tick before swap: %s", tick);
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -500e18,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            settings,
            ZERO_BYTES
        );
        uint256 hookBalanceAfterToken0 = s_key.currency0.balanceOf(
            address(hook)
        );
        console2.log(
            "Hook balance after token0 swap: %s",
            hookBalanceAfterToken0
        );
        uint256 hookBalanceAfterToken1 = s_key.currency1.balanceOf(
            address(hook)
        );
        console2.log(
            "Hook currency0 balance after swap matched: %s",
            s_key.currency0.balanceOf(address(hook))
        );
        console2.log(
            "Hook currency1 balance after swap matched: %s",
            s_key.currency1.balanceOf(address(hook))
        );
        console2.log(
            "Vault currency0 balance after swap matched: %s",
            s_key.currency0.balanceOf(address(vault))
        );
        console2.log(
            "Vault currency1 balance after swap matched: %s",
            s_key.currency1.balanceOf(address(vault))
        );
        console2.log(
            "PM currency0 balance after swap matched: %s",
            s_key.currency0.balanceOf(address(manager))
        );
        console2.log(
            "PM currency1 balance after swap matched: %s",
            s_key.currency1.balanceOf(address(manager))
        );
        console2.log(
            "HOOK Claims0 balance after swap matched: %s",
            manager.balanceOf(address(hook), s_key.currency0.toId())
        );
        console2.log(
            "HOOK Claims1 balance after swap matched: %s",
            manager.balanceOf(address(hook), s_key.currency1.toId())
        );

        console2.log(
            "USER1 balance after swap matched: %s",
            s_key.currency0.balanceOf(USER)
        );
        console2.log(
            "USER1 balance after swap matched: %s",
            s_key.currency1.balanceOf(USER)
        );
        console2.log(
            "USER2 balance after swap matched: %s",
            s_key.currency0.balanceOf(USER2)
        );
        console2.log(
            "USER2 balance after swap matched: %s",
            s_key.currency1.balanceOf(USER2)
        );
        console2.log(
            "Hook balance of TOken0 after swap matched: %s",
            s_key.currency0.balanceOf(address(hook))
        );
        console2.log(
            "Hook balance of TOken1 after swap matched: %s",
            s_key.currency1.balanceOf(address(hook))
        );
        vm.stopPrank();
    }
}
