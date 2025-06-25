const ethers = require("ethers");
import { abiPoolTestSwap } from "../abis/abiPoolTestSwap";
import { abiCustomERC20 } from "../abis/abiCustomERC20";
require("dotenv").config();
import {
  addressPoolSwapTestRouter_BASE,
  ADDRES_HOOK_BASE,
  USDC_BASE,
  DAI_BASE,
  ADDRESS_VAULT_BASE,
} from "../abis/addressConstantsMain";
import { abiDai } from "../abis/abiDai";

interface swapDirectlyParams {
  tokenToSell: string;
  amountToSell: string;
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
export default async function swapDirectlyDAI({
  tokenToSell,
  amountToSell,
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

    console.log("estoy trabajando en swapDirectlyDAI");

    const swapTestContract = new ethers.Contract(
      addressPoolSwapTestRouter_BASE,
      abiPoolTestSwap,
      signer
    );

    const DAIContract = new ethers.Contract(DAI_BASE, abiDai, signer);

    const [currency0, currency1] = getCurrencies(tokenToSell);
    const key: PoolKey = {
      currency0,
      currency1,
      fee: DYNAMIC_FEE,
      tickSpacing: 1,
      hooks: ADDRES_HOOK_BASE,
    };

    let zeroForOne = currency0 === tokenToSell;
    //! No format again to 1e18, it comes formatted form the bridgeTokensToBase.ts
    // let amountToSellFormatted = await ethers.utils.parseUnits(amountToSell, 18);
    const params: SwapParams = {
      zeroForOne: zeroForOne, // true = vendes currency0 DAI
      amountSpecified: BigInt(-amountToSell), // negativo ⇢ exact input
      sqrtPriceLimitX96: MIN_SQRT_PRICE,
    };

    const testSettings: TestSettings = {
      takeClaims: false,
      settleUsingBurn: false,
    };

    const hookData = "0x";
    const tx1 = await DAIContract.approve(
      swapTestContract.address,
      ethers.constants.MaxUint256 // Usar MaxUint256 para permitir múltiples swaps
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
      if (tokenToSell.toLowerCase() < USDC_BASE.toLowerCase()) {
        return [tokenToSell, USDC_BASE];
      } else {
        return [USDC_BASE, tokenToSell];
      }
    }
  } catch (error) {
    console.error("Error en el swap:", error);
    throw error;
  }
}
