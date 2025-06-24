// //!Solo falta cambiar el abi y el addressSC

// import {
//   createWalletClient,
//   custom,
//   encodeFunctionData,
//   getContract,
//   encodeAbiParameters,
//   parseAbiParameters,
//   toHex,
//   encodePacked,
//   createPublicClient,
// } from "viem";
// import { waitForTransactionReceipt } from "viem/actions";
// import { sepolia, baseSepolia } from "viem/chains";
// import { parseEther } from "viem/utils";

// //! Aqui van las abis y constants

// const MulticallContractAddressBaseSepolia =
//   "0x924a9f036260ddd5808007e1aa95f08ed08aa569";
// const Base_SpokePool = "0x82b564983ae7274c86695917bbf8c99ecb6f0f8f";

// interface BuildTransaction {
//   senderAddress: string;
//   tokenToSell: string;
//   amountToSell: string;
//   minimumAmountToReceive: string;
// }

// export default async function acrossSwapToBase({
//   senderAddress,
//   tokenToSell,
//   amountToSell,
//   minimumAmountToReceive,
// }: BuildTransaction) {
//   try {
//     const publicClient = createPublicClient({
//       chain: baseSepolia,
//       transport: custom(window.ethereum!),
//     });
//     const walletClient = createWalletClient({
//       account: senderAddress,
//       chain: baseSepolia,
//       transport: custom(window.ethereum!),
//     });

//     console.log("Estoy aqui");
//   } catch (error) {
//     console.error("Error:", error);
//     throw error;
//   }
// }
