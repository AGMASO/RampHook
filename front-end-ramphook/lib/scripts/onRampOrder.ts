const ethers = require("ethers");
import { abiPoolTestSwap } from "../abis/abiPoolTestSwap";
import { abiCustomERC20 } from "../abis/abiCustomERC20";
import { abiVault } from "@/lib/abis/abiVault";
import { Interface } from "ethers/lib/utils.js";
require("dotenv").config();
import {
  ADDRES_HOOK,
  USDCm,
  USDTm,
  ADDRESS_VAULT,
  addressPoolSwapTestRouter,
} from "../abis/addressConstantsTest";

interface onRampOrderProps {
  amountToSell: string;
  receiverAddress: string;
  desiredToken: string;
}

interface onRampOrderData {
  amount: BigInt; // int256
  receiverAddress: string; // address
  desiredToken: string; // address
}

export default async function onRampOrder({
  amountToSell,
  receiverAddress,
  desiredToken,
}: onRampOrderProps) {
  console.log("estoy aqui en onrampOrder");

  try {
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    // Request access to the MetaMask account
    await provider.send("eth_requestAccounts", []);
    const signer = provider.getSigner();

    console.log(signer);

    console.log("estoy trabajando");

    const vaultContract = new ethers.Contract(ADDRESS_VAULT, abiVault, signer);

    const USDCmContract = new ethers.Contract(USDCm, abiCustomERC20, signer);

    let amountToSellFormatted = await ethers.utils.parseUnits(amountToSell, 6);

    const onRampData: onRampOrderData = {
      amount: BigInt(amountToSellFormatted), // negativo para indicar "exact input"
      receiverAddress: receiverAddress,
      desiredToken: desiredToken, // dirección del token deseado
    };

    console.log("Estoy Aqui 2");
    const ownerAddress = await vaultContract.owner();
    console.log("Owner Address:", ownerAddress);
    const balanceUSDCmVault = await USDCmContract.balanceOf(ADDRESS_VAULT);
    console.log("Balance USDCm en el vault:", balanceUSDCmVault.toString());
    const allowanceBefore = await USDCmContract.allowance(
      ADDRESS_VAULT,
      ADDRES_HOOK
    );
    console.log(
      `Allowance USDCm del Vault hacia Hook (antes): ${allowanceBefore.toString()}`
    );

    const tx1 = await vaultContract.approveHook(
      USDCm,
      ADDRES_HOOK,
      amountToSellFormatted
    );
    await tx1.wait();
    console.log("Estoy Aqui 3");
    const tx11 = await vaultContract.approveHook(
      USDTm,
      ADDRES_HOOK,
      amountToSellFormatted
    );
    await tx11.wait();

    const tx2 = await vaultContract.onramp(onRampData);
    const receipt = await tx2.wait();

    console.log("Transacción completada:", receipt);
    console.log("Hash de la transacción:", receipt.transactionHash);
  } catch (error) {
    console.error("Error en el swap:", error);
    throw error;
  }
}
