// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRampHookV1 {
    error OnlyVaultCanCreateOnRampOrder();
    event OnRampOrderCreated(
        bool zeroForOne,
        address receiver,
        int256 amountSpecified
    );
    struct OnRampOrder {
        int256 inputAmount;
        address receiver;
        bool fulfilled;
    }
}
