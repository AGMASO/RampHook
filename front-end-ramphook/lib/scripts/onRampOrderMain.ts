const ethers = require("ethers");
import { abiPoolTestSwap } from "../abis/abiPoolTestSwap";
import { abiCustomERC20 } from "../abis/abiCustomERC20";
import { abiVault } from "@/lib/abis/abiVault";
import { Interface } from "ethers/lib/utils.js";
import { abiUSDCBASE } from "../abis/abiUSDCBASE";
require("dotenv").config();
import {
  addressPoolSwapTestRouter_BASE,
  ADDRES_HOOK_BASE,
  USDC_BASE,
  DAI_BASE,
  ADDRESS_VAULT_BASE,
} from "../abis/addressConstantsMain";

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

export default async function onRampOrderMain({
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

    const vaultContract = new ethers.Contract(
      ADDRESS_VAULT_BASE,
      abiVault,
      signer
    );

    const USDCBaseContract = new ethers.Contract(
      USDC_BASE,
      abiUSDCBASE,
      signer
    );

    let amountToSellFormatted = await ethers.utils.parseUnits(amountToSell, 6);

    const onRampData: onRampOrderData = {
      amount: BigInt(amountToSellFormatted),
      receiverAddress: receiverAddress,
      desiredToken: desiredToken, // dirección del token deseado
    };

    console.log("Estoy Aqui 2");
    const ownerAddress = await vaultContract.owner();
    console.log("Owner Address:", ownerAddress);
    const balanceUSDCVault = await USDCBaseContract.balanceOf(
      ADDRESS_VAULT_BASE
    );
    console.log("Balance USDCm en el vault:", balanceUSDCVault.toString());
    const allowanceBefore = await USDCBaseContract.allowance(
      ADDRESS_VAULT_BASE,
      ADDRES_HOOK_BASE
    );
    console.log(
      `Allowance USDCm del Vault hacia Hook (antes): ${allowanceBefore.toString()}`
    );

    const tx1 = await vaultContract.approveHook(
      USDC_BASE,
      ADDRES_HOOK_BASE,
      amountToSellFormatted
    );
    await tx1.wait();
    console.log("Estoy Aqui 3");
    const tx11 = await vaultContract.approveHook(
      DAI_BASE,
      ADDRES_HOOK_BASE,
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
