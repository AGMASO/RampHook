const ethers = require("ethers");
import { abiPoolTestSwap } from "../abis/abiPoolTestSwap";
import { abiCustomERC20 } from "../abis/abiCustomERC20";
require("dotenv").config();
import {
  ADDRES_HOOK,
  USDCm,
  USDTm,
  ADDRESS_VAULT,
  addressPoolSwapTestRouter,
} from "../abis/addressConstants";

interface swapDirectlyParams {
  senderAddress: string;
  tokenToSell: string;
  amountToSell: string;
  minimumAmountToReceive: string;
}

interface PoolKey {
  currency0: string;
  currency1: string;
  fee: number; // uint24
  tickSpacing: number; // int24
  hooks: string;
}
interface SwapParams {
  zeroForOne: boolean;
  amountSpecified: BigInt; // int256
  sqrtPriceLimitX96: BigInt; // uint160
}
interface TestSettings {
  takeClaims: boolean;
  settleUsingBurn: boolean;
}
export default async function swapDirectlyUSDT({
  senderAddress,
  tokenToSell,
  amountToSell,
  minimumAmountToReceive,
}: swapDirectlyParams) {
  console.log("estoy aqui");

  const MIN_SQRT_PRICE = 4295128739n + 1n;
  /// @dev The maximum value that can be returned from #getSqrtPriceAtTick. Equivalent to getSqrtPriceAtTick(MAX_TICK)
  const MAX_SQRT_PRICE =
    1461446703485210103287273052203988822378723970342n - 1n;
  const DYNAMIC_FEE = 0x800000; // 0.05% fee, puedes cambiarlo si es necesario
  try {
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    // Request access to the MetaMask account
    await provider.send("eth_requestAccounts", []);
    const signer = provider.getSigner();

    console.log(signer);

    console.log("estoy trabajando");

    const swapTestContract = new ethers.Contract(
      addressPoolSwapTestRouter,
      abiPoolTestSwap,
      signer
    );

    const USDTmContract = new ethers.Contract(USDTm, abiCustomERC20, signer);

    const [currency0, currency1] = getCurrencies(tokenToSell);
    const key: PoolKey = {
      currency0,
      currency1,
      fee: DYNAMIC_FEE,
      tickSpacing: 1,
      hooks: ADDRES_HOOK,
    };

    let zeroForOne = currency0 === tokenToSell;
    let amountToSellFormatted = await ethers.utils.parseUnits(amountToSell, 6);
    const params: SwapParams = {
      zeroForOne: zeroForOne, // false = vendes currency1 USDT
      amountSpecified: BigInt(-amountToSellFormatted), // negativo ⇢ exact input
      sqrtPriceLimitX96: MAX_SQRT_PRICE,
    };

    const testSettings: TestSettings = {
      takeClaims: false,
      settleUsingBurn: false,
    };

    const hookData = "0x";
    const tx1 = await USDTmContract.approve(
      swapTestContract.address,
      amountToSellFormatted
    );
    await tx1.wait();

    const tx2 = await swapTestContract.swap(
      key,
      params,
      testSettings,
      hookData
    );
    const receipt = await tx2.wait();

    console.log("Transacción completada:", receipt);
    console.log("Hash de la transacción:", receipt.transactionHash);

    function getCurrencies(tokenToSell: string): [string, string] {
      if (tokenToSell.toLowerCase() < USDCm.toLowerCase()) {
        return [tokenToSell, USDCm];
      } else {
        return [USDCm, tokenToSell];
      }
    }
  } catch (error) {
    console.error("Error en el swap:", error);
    throw error;
  }
}
