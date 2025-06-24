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
} from "../abis/addressConstants";

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
    // address token,
    // address hook,
    // uint256 amount
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
    // try {
    //   await vaultContract.callStatic.approveHook(
    //     USDCm,
    //     ADDRES_HOOK,
    //     amountToSellFormatted
    //   );
    //   console.log("callStatic.approveHook: ¡no revertiría!");
    // } catch (err) {
    //   tryDecodeRevert(err, vaultContract.interface);
    //   throw err; // opcional – re-propaga para el flujo de la app
    // }

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

    // function getCurrencies(tokenToSell: string): [string, string] {
    //   // Según las reglas de UniswapV4, currency0 siempre debe tener la dirección más pequeña
    //   if (tokenToSell.toLowerCase() < USDCm.toLowerCase()) {
    //     return [tokenToSell, USDCm];
    //   } else {
    //     return [USDCm, tokenToSell];
    //   }
    // }
    // function tryDecodeRevert(err: any, iface?: Interface) {
    //   // 1. localizar dónde viene el field con los bytes
    //   let raw: any =
    //     err?.error?.data?.data ?? // provider < v6
    //     err?.error?.data ??
    //     err?.data ??
    //     err?.binary ?? // algunas implementaciones
    //     null;

    //   if (!raw) {
    //     console.error("⛔️  Sin error.data que decodificar:", err);
    //     return;
    //   }

    //   // 2. normalizar a hex-string
    //   if (raw instanceof Uint8Array) raw = ethers.utils.hexlify(raw);
    //   if (typeof raw === "number") raw = ethers.utils.hexStripZeros(raw);
    //   if (typeof raw !== "string") {
    //     console.error("⛔️  Formato desconocido:", raw);
    //     return;
    //   }

    //   console.log("🗒  raw revert data:", raw);

    //   // 3. intentar decodificar con la ABI (custom errors)
    //   if (iface) {
    //     try {
    //       const decoded = iface.parseError(raw);
    //       console.error("⛔️  Revert ►", decoded.name, decoded.args);
    //       return;
    //     } catch {
    //       /* no era un custom error */
    //     }
    //   }

    //   // 4. intentar error estándar Error(string)
    //   const errorSig = raw.slice(0, 10);
    //   if (errorSig === "0x08c379a0" /* Error(string) */) {
    //     const reason = ethers.utils.toUtf8String("0x" + raw.slice(10));
    //     console.error("⛔️  Revert ► Error(string):", reason);
    //   } else {
    //     console.error("⛔️  Revert ► selector:", errorSig);
    //   }
    // }
  } catch (error) {
    console.error("Error en el swap:", error);
    throw error;
  }
}
