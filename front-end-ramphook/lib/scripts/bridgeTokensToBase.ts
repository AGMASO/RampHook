import { ethers } from "ethers";
import { abiSpokeContract } from "../abis/abiSpokeContract";
import { abiDai } from "../abis/abiDai";
import swapDirectlyDAI from "./swapDirectlyDAI";

interface BridgeTokensToBaseProps {
  senderAddress: string;
  tokenToSell: string;
  amountToSell: string;
  minimumAmountToReceive: string;
}
export default async function bridgeTokensToBase({
  senderAddress,
  tokenToSell,
  amountToSell,
  minimumAmountToReceive,
}: BridgeTokensToBaseProps) {
  console.log("Bridging tokens to Base...");
  const SPOKECONTRACT_MAINNET = "0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5";
  const ORIGIN_CHAIN_ID = 1; // Mainnet
  const DESTINATION_CHAIN_ID = 8453; // Base Mainnet
  const DAI_MAIN = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
  const DAI_BASE = "0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb";

  const ACROSS_API_URL = "https://app.across.to/api/suggested-fees";
  const INPUT_TOKEN = DAI_MAIN.toLowerCase();
  const OUTPUT_TOKEN = DAI_BASE.toLowerCase();
  const ORIGINCHAINID = ORIGIN_CHAIN_ID;
  const DESTINATIONCHAINID = DESTINATION_CHAIN_ID;
  const AMOUNT = ethers.utils.parseUnits(amountToSell, 18).toString();
  const RECIPIENT = senderAddress.toLowerCase();

  const url = new URL(ACROSS_API_URL);
  url.searchParams.set("inputToken", INPUT_TOKEN);
  url.searchParams.set("outputToken", OUTPUT_TOKEN);
  url.searchParams.set("originChainId", ORIGINCHAINID.toString());
  url.searchParams.set("destinationChainId", DESTINATIONCHAINID.toString());
  url.searchParams.set("amount", AMOUNT);
  url.searchParams.set("recipient", RECIPIENT);
  console.log("Fetching quote from Across API:", url.toString());
  console.log("Fetching quote from:", url.toString());

  const res = await fetch(url.toString(), {
    method: "GET",
    headers: {
      "Content-Type": "application/json",
    },
  });
  console.log("Response status:", res.status);

  if (!res.ok) {
    const errorText = await res.text();
    console.error("API Error:", errorText);
    throw new Error(`Across API error ${res.status}: ${errorText}`);
  }

  const quote = await res.json();
  console.log("Quote from Across API:", quote);
  let outputAmount = quote.outputAmount;
  try {
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    // Request access to the MetaMask account
    await provider.send("eth_requestAccounts", []);
    const signer = provider.getSigner();

    console.log(signer);

    console.log("estoy trabajando");

    const spokeContract = new ethers.Contract(
      SPOKECONTRACT_MAINNET,
      abiSpokeContract,
      signer
    );
    const daiMainnet = new ethers.Contract(DAI_MAIN, abiDai, signer);
    const tx1 = await daiMainnet.approve(spokeContract.address, AMOUNT);
    await tx1.wait();

    //!Prepare data for depositV3
    const depositor = senderAddress.toLowerCase();
    const recipient = senderAddress.toLowerCase();
    const inputToken = DAI_MAIN.toLowerCase();
    const outputToken = DAI_BASE.toLowerCase();
    const inputAmount = AMOUNT;
    const outputAmount = quote.outputAmount.toString();
    const destinationChainId = DESTINATION_CHAIN_ID;
    const exclusiveRelayer = quote.exclusiveRelayer;
    const quoteTimestamp = quote.timestamp;
    const fillDeadline = quote.fillDeadline;
    const exclusivityDeadline = quote.exclusivityDeadline;
    const message = "0x";
    // Agregar logging para debug
    console.log("Deposit parameters:", {
      depositor,
      recipient,
      inputToken,
      outputToken,
      inputAmount,
      outputAmount,
      destinationChainId,
      exclusiveRelayer,
      quoteTimestamp,
      fillDeadline,
      exclusivityDeadline,
      message,
    });
    const tx2 = await spokeContract.depositV3(
      depositor,
      recipient,
      inputToken,
      outputToken,
      inputAmount,
      outputAmount,
      destinationChainId,
      exclusiveRelayer,
      quoteTimestamp,
      fillDeadline,
      exclusivityDeadline,
      message,
      { value: 0 }
    );
    const reciept = await tx2.wait();
    console.log("Transaction successful:", reciept.transactionHash);
  } catch (error) {
    console.error("Error en el swap:", error);
    throw error;
  }
  try {
    // Intentar cambiar la red
    const BASE_MAINNET_CHAIN_ID = "0x" + DESTINATION_CHAIN_ID.toString(16);
    await window.ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: BASE_MAINNET_CHAIN_ID }],
    });

    console.log("Switched to Base network successfully");
    console.log("Output amount to sell:", outputAmount);
    await swapDirectlyDAI({
      tokenToSell: DAI_BASE,
      amountToSell: outputAmount,
    });
    console.log("Swap completed successfully on Base network");
  } catch (switchError: any) {
    console.error("Error switching network:", switchError);

    throw switchError;
  }
}
