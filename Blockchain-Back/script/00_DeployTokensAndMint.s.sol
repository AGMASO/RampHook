// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {CustomERC20} from "../src/mocks/CustomERC20.sol";

contract DeployTokensAndMintScript is Script {
    uint256 private pk = vm.envUint("PRIVATE_KEY");
    address private _deployer = vm.addr(pk);
    address USERONRAMPER = 0xEeCdf10373bdEee9C66150443b63C15B297D6000;
    address USERSWAPPER = 0x4B132611cdD369384A3CAB8104baAB0279dA9bdE;
    // address vault = 0x4A360497111D4888f79d7CFeC697562611b7F62f;
    // address currency0 = 0xB9a9553E08e5AFc8a7E16613572CC8F96B3143F9;
    CustomERC20 public token0;
    CustomERC20 public token1;

    function run() external {
        vm.startBroadcast(_deployer);

        // Deploy MockERC20 tokens
        token0 = new CustomERC20("USD Coin Mock", "USDCm", 6);
        token0.mint(_deployer, 1_000_000 * 10 ** 6); // Mint 1,000,000 USDTm to deployer
        token0.mint(USERSWAPPER, 1_000_000 * 10 ** 6); // Mint 1,000,000 USDCm to deployer
        token0.mint(USERONRAMPER, 1_000_000 * 10 ** 6); // Mint 1,000,000 USDTm to deployer
        // token0.mint(vault, 1_000_000 * 10 ** 6); // Mint 1,000,000 USDCm to vault
        // CustomERC20(0xB9a9553E08e5AFc8a7E16613572CC8F96B3143F9).mint(
        //     vault,
        //     1_000_000 * 10 ** 6
        // ); // Mint 1,000,000 USDCm to deployer

        token1 = new CustomERC20("Tether USD Mock", "USDTm", 6);
        token1.mint(_deployer, 1_000_000 * 10 ** 6); // Mint 1,000,000 USDTm to deployer
        token1.mint(USERSWAPPER, 1_000_000 * 10 ** 6); // Mint 1,000,000 USDTm to deployer
        token1.mint(USERONRAMPER, 1_000_000 * 10 ** 6); // Mint 1,000,000 USDTm to deployer

        vm.stopBroadcast();
    }
}
