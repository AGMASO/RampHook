// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";

import {IUniswapV4Router04} from "hookmate/interfaces/router/IUniswapV4Router04.sol";
import {AddressConstants} from "hookmate/constants/AddressConstants.sol";

/// @notice Shared configuration between scripts
contract BaseScript is Script {
    IPermit2 immutable permit2 =
        IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IPoolManager immutable poolManager;
    IPositionManager immutable positionManager;
    IUniswapV4Router04 immutable swapRouter;
    address immutable deployerAddress;
    uint256 private pk = vm.envUint("PRIVATE_KEY");
    address private _deployer = vm.addr(pk);

    /////////////////////////////////////
    // --- Configure These ---
    /////////////////////////////////////
    IERC20 internal constant token0 =
        IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913); //USDC Base
    IERC20 internal constant token1 =
        IERC20(0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2); //USDT Base

    IHooks constant hookContract =
        IHooks(0x8c21Ad0a8E9D9FDE87DC479831dd7222D5486088); //RampHook address deployed, actualizar

    /////////////////////////////////////

    Currency immutable currency0;
    Currency immutable currency1;

    constructor() {
        poolManager = IPoolManager(
            AddressConstants.getPoolManagerAddress(block.chainid)
        );
        positionManager = IPositionManager(
            payable(AddressConstants.getPositionManagerAddress(block.chainid))
        );
        swapRouter = IUniswapV4Router04(
            payable(AddressConstants.getV4SwapRouterAddress(block.chainid))
        );

        deployerAddress = getDeployer();

        (currency0, currency1) = getCurrencies();

        // deal(Currency.unwrap(currency1), address(_deployer), 3000 ether);
        // deal(Currency.unwrap(currency0), address(_deployer), 3000 ether);
        vm.label(address(token0), "Token0");
        vm.label(address(token1), "Token1");

        vm.label(address(deployerAddress), "Deployer");
        vm.label(address(poolManager), "PoolManager");
        vm.label(address(positionManager), "PositionManager");
        vm.label(address(swapRouter), "SwapRouter");
        vm.label(address(hookContract), "HookContract");
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

    function getDeployer() public returns (address) {
        address[] memory wallets = vm.getWallets();

        require(wallets.length > 0, "No wallets found");

        return wallets[0];
    }
}
