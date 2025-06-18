// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

import {BaseScript} from "./base/BaseScript.sol";

import {RampHookV1} from "../src/RampHookV1.sol";
import {Vault} from "../src/Vault.sol";

/// @notice Mines the address and deploys the Counter.sol Hook contract
contract DeployHookScript is BaseScript {
    uint256 private pk = vm.envUint("PRIVATE_KEY");
    address private _deployer = vm.addr(pk);

    function run() public {
        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
                Hooks.BEFORE_SWAP_FLAG |
                Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        vm.startBroadcast(_deployer);
        Vault vault = new Vault();

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(poolManager, address(vault));
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_FACTORY,
            flags,
            type(RampHookV1).creationCode,
            constructorArgs
        );

        // Deploy the hook using CREATE2

        RampHookV1 ramphook = new RampHookV1{salt: salt}(
            poolManager,
            address(vault)
        );

        vm.stopBroadcast();

        //TransferOwnership to the deployer
        vm.prank(CREATE2_FACTORY);
        ramphook.transferOwnership(_deployer);

        require(
            address(ramphook) == hookAddress,
            "DeployHookScript: Hook Address Mismatch"
        );
    }
}
