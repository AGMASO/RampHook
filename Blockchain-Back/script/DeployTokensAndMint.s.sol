// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {CustomERC20} from "../src/mocks/CustomERC20.sol";

contract DeployTokensAndMintScript is Script {
    uint256 private pk = vm.envUint("PRIVATE_KEY");
    address private _deployer = vm.addr(pk);
    address USERONRAMPER = 0xEeCdf10373bdEee9C66150443b63C15B297D6000;
    address USERSWAPPER = 0x4B132611cdD369384A3CAB8104baAB0279dA9bdE;
    CustomERC20 public token0;
    CustomERC20 public token1;

    function run() external {
        vm.startBroadcast(_deployer);

        // Deploy MockERC20 tokens
        token0 = new CustomERC20("USD Coin Mock", "USDCm", 6);
        token0.mint(_deployer, 1_000_000 * 10 ** 6); // Mint 1,000,000 USDTm to deployer
        token0.mint(USERSWAPPER, 1_000_000 * 10 ** 6); // Mint 1,000,000 USDCm to deployer
        token0.mint(USERONRAMPER, 1_000_000 * 10 ** 6); // Mint 1,000,000 USDTm to deployer
        // CustomERC20(0x8524282267080Ab2ac08445889FE19616ca8Cc89).mint(
        //     USERSWAPPER,
        //     1_000_000 * 10 ** 6
        // ); // Mint 1,000,000 USDCm to deployer

        token1 = new CustomERC20("Tether USD Mock", "USDTm", 6);
        token1.mint(_deployer, 1_000_000 * 10 ** 6); // Mint 1,000,000 USDTm to deployer
        token1.mint(USERSWAPPER, 1_000_000 * 10 ** 6); // Mint 1,000,000 USDTm to deployer
        token1.mint(USERONRAMPER, 1_000_000 * 10 ** 6); // Mint 1,000,000 USDTm to deployer

        vm.stopBroadcast();
    }
}
