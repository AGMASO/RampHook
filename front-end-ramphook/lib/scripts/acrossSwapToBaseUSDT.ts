// // acrossSwapToBase.ts
// // ---------------------------------------------------------------------------------
// // ❶ Imports
// // ---------------------------------------------------------------------------------

// import {
//   createWalletClient,
//   createPublicClient,
//   custom,
//   encodeFunctionData,
//   encodeAbiParameters,
//   parseAbi,
//   Address,
//   Hex,
//   parseUnits,
// } from "viem";
// import { waitForTransactionReceipt } from "viem/actions";
// import { baseSepolia } from "viem/chains";
// import { abiPoolTestSwap } from "../abis/abiPoolTestSwap";
// const PoolSwapTestAbi = abiPoolTestSwap;
// // ---------------------------------------------------------------------------------
// // ❷ ABIs mínimos
// // ---------------------------------------------------------------------------------
// // Ethers v6
// import { ethers } from "ethers";

// /** ----------------------------------------------------------------
//  *  ABI - solo necesitamos la definición de swap para codificarla.
//  *  (Puedes pegar aquí tu abiPoolTestSwap completo si lo prefieres)
//  *  ---------------------------------------------------------------- */
// const abiPoolTestSwapOnly = [
//   {
//     type: "function",
//     name: "swap",
//     stateMutability: "payable",
//     inputs: [
//       {
//         name: "key",
//         type: "tuple",
//         components: [
//           { name: "currency0", type: "address" },
//           { name: "currency1", type: "address" },
//           { name: "fee", type: "uint24" },
//           { name: "tickSpacing", type: "int24" },
//           { name: "hooks", type: "address" },
//         ],
//       },
//       {
//         name: "params",
//         type: "tuple",
//         components: [
//           { name: "zeroForOne", type: "bool" },
//           { name: "amountSpecified", type: "int256" },
//           { name: "sqrtPriceLimitX96", type: "uint160" },
//         ],
//       },
//       {
//         name: "testSettings",
//         type: "tuple",
//         components: [
//           { name: "takeClaims", type: "bool" },
//           { name: "settleUsingBurn", type: "bool" },
//         ],
//       },
//       { name: "hookData", type: "bytes" },
//     ],
//     outputs: [{ name: "delta", type: "int256" }],
//   },
// ];

// /** ---------------------------------------------------------------
//  *  Función genérica para crear el mensaje INSTRUCTIONS
//  *  --------------------------------------------------------------*/
// function generateMessageForMulticallSwap(
//   userAddress: string, // fallbackRecipient
//   poolContractAddress: string, // contrato PoolSwapTest
//   key: {
//     currency0: string;
//     currency1: string;
//     fee: number; // uint24
//     tickSpacing: number; // int24
//     hooks: string;
//   },
//   params: {
//     zeroForOne: boolean;
//     amountSpecified: bigint; // int256  (usa BigInt o ethers.parseUnits)
//     sqrtPriceLimitX96: bigint; // uint160
//   },
//   testSettings: {
//     takeClaims: boolean;
//     settleUsingBurn: boolean;
//   },
//   hookData: string = "0x", // bytes
//   ethValue: bigint = 0n // msg.value para la llamada (swap es payable)
// ): string {
//   // 1. Codificamos la llamada a swap
//   const poolInterface = new ethers.Interface(abiPoolTestSwapOnly);
//   const swapCalldata = poolInterface.encodeFunctionData("swap", [
//     key,
//     params,
//     testSettings,
//     hookData,
//   ]);

//   // 2. Construimos la tuple Instructions:
//   //    tuple(
//   //      tuple(address target, bytes callData, uint256 value)[] calls,
//   //      address fallbackRecipient
//   //    )
//   const abiCoder = ethers.AbiCoder.defaultAbiCoder();
//   return abiCoder.encode(
//     [
//       "tuple(" +
//         "tuple(" +
//         "address target," +
//         "bytes callData," +
//         "uint256 value" +
//         ")[]," +
//         "address fallbackRecipient" +
//         ")",
//     ],
//     [
//       [
//         [[poolContractAddress, swapCalldata, ethValue]], // array de 1 llamada
//         userAddress, // fallbackRecipient
//       ],
//     ]
//   );
// }

// // ---------------------------------------------------------------------------------
// // ❹ Constantes (multicall, spoke pool, router…)
// // ---------------------------------------------------------------------------------
// const MULTICALL_HANDLER_BASE_SEPOLIA =
//   "0x924a9f036260DdD5808007e1Aa95F08eD08aA569" as Address; // Ya lo tenías
// const BASE_SPOKE_POOL = "0x82b564983AE7274c86695917bBf8c99eCb6F0F8F" as Address; // Ya lo tenías
// const SWAP_ROUTER_ADDRESS =
//   "0x5e688a383919dF58EF5840721B2eb5105071BF7E" as Address;
// const USDCm = "0xB9a9553E08e5AFc8a7E16613572CC8F96B3143F9" as Address; // USDC en Base Sepolia
// const USDCmSepolia = "0xb6344084448eb7f9Cff43953d95FCE2b9fda1Ed8" as Address; // USDC en Sepolia
// const USDTmSepolia = "0xAA67B322aE86e1000686F163471e81b3158340C7" as Address; // USDT en Sepolia
// const MIN_SQRT_PRICE = 4295128739n + 1n;
// /// @dev The maximum value that can be returned from #getSqrtPriceAtTick. Equivalent to getSqrtPriceAtTick(MAX_TICK)
// const MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342n - 1n;
// const ORIGIN_CHAIN_ID = 11155111; // Sepolia
// const DESTINATION_CHAIN_ID = 84532; // Base Sepolia
// // ---------------------------------------------------------------------------------
// // ❺ Helper: genera el message en formato Across
// // ---------------------------------------------------------------------------------

// // ---------------------------------------------------------------------------------
// // ❻ Interfaz pública (input que recibes en tu app)
// // ---------------------------------------------------------------------------------
// interface BuildTransaction {
//   senderAddress: Address;
//   tokenToSell: Address; // == tokenIn / currency0
//   amountToSell: bigint; // uint256 (decimales del token)
//   minimumAmountToReceive: bigint; // por si lo necesitas para slippage / UI
// }

// // ---------------------------------------------------------------------------------
// // ❼ Función principal
// // ---------------------------------------------------------------------------------
// export default async function acrossSwapToBaseUSDT({
//   senderAddress,
//   tokenToSell,
//   amountToSell,
//   minimumAmountToReceive,
// }: BuildTransaction) {
//   try {
//     // --- Clientes viem ---
//     const publicClient = createPublicClient({
//       chain: baseSepolia,
//       transport: custom(window.ethereum!),
//     });
//     const walletClient = createWalletClient({
//       account: senderAddress,
//       chain: baseSepolia,
//       transport: custom(window.ethereum!),
//     });

//     // --- 1. Define structs específicos del swap ---
//     const [currency0, currency1] = getCurrencies(tokenToSell);

//     // const key: PoolKey = {
//     //   currency0,
//     //   currency1,
//     //   fee: 0x800000, // DYNAMIC_FEE_FLAG
//     //   tickSpacing: 1,
//     //   hooks: "0xA11444D0C7085ce34D8CCcEd3fe543B658246088",
//     // };
//     // let zeroForOne = currency0 === tokenToSell;
//     // const params: SwapParams = {
//     //   zeroForOne: zeroForOne, // true si vendemos currency0, false si vendemos currency1
//     //   amountSpecified: -amountToSell, // exactIn  (negativo)
//     //   sqrtPriceLimitX96: zeroForOne ? MIN_SQRT_PRICE : MAX_SQRT_PRICE, // TickMath.MIN_SQRT_PRICE+1
//     // };

//     // const settings: TestSettings = {
//     //   takeClaims: false,
//     //   settleUsingBurn: false,
//     // };

//     // --- 2. Genera el message ---
//     const messageEncoded = generateMessageForMulticallSwap(
//       user,
//       poolAddress,
//       /* key ------------------------------------------------------------------ */
//       {
//         currency0: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // USDC
//         currency1: "0xC02aaA39b223FE8D0A0E5C4F27eAD9083C756Cc2", // WETH
//         fee: 500, // 0.05 %  (Uniswap-style)
//         tickSpacing: 60,
//         hooks: ethers.ZeroAddress,
//       },
//       /* params ---------------------------------------------------------------- */
//       {
//         zeroForOne: true, // USDC -> WETH
//         amountSpecified: ethers.parseUnits("1000", 6), // 1 000 USDC
//         sqrtPriceLimitX96: 0n, // sin límite
//       },
//       /* testSettings ---------------------------------------------------------- */
//       { takeClaims: false, settleUsingBurn: false },
//       /* hookData */ "0x",
//       /* ethValue */ 0n
//     );
//     // const message = buildAcrossMessage(
//     //   senderAddress,
//     //   SWAP_ROUTER_ADDRESS,
//     //   tokenToSell,
//     //   amountToSell,
//     //   key,
//     //   params,
//     //   settings
//     // );

//     console.log("Encoded Across message →", messageEncoded);
//     // Aquí puedes:
//     //   • Llamar al endpoint /suggested-fees de Across,
//     //   • Construir depositV3 con { recipient: MULTICALL_HANDLER_BASE_SEPOLIA, message, ... }
//     //   • Enviar la tx vía walletClient.writeContract / walletClient.sendTransaction
//     //   • Esperar confirmación con waitForTransactionReceipt
//     // TODO: añade la lógica que ya tengas para depositV3
//     const ACROSS_HOST =
//       ORIGIN_CHAIN_ID === 11155111 || DESTINATION_CHAIN_ID === 84532
//         ? "https://testnet.across.to/api"
//         : "https://app.across.to/api";
//     const RECIPIENT = MULTICALL_HANDLER_BASE_SEPOLIA.toLowerCase();
//     const INPUT_TOKEN = tokenToSell.toLowerCase();
//     const OUTPUT_TOKEN = USDTmSepolia.toLowerCase();
//     let amountIne6 = parseUnits(amountToSell.toString(), 6); // Convertir a e6 (ejemplo: USDT tiene 6 decimales)
//     const url = new URL("/suggested-fees", ACROSS_HOST);
//     url.searchParams.set("inputToken", INPUT_TOKEN);
//     url.searchParams.set("outputToken", OUTPUT_TOKEN);
//     url.searchParams.set("originChainId", ORIGIN_CHAIN_ID.toString());
//     url.searchParams.set("destinationChainId", DESTINATION_CHAIN_ID.toString());
//     url.searchParams.set("amount", amountIne6.toString()); // uint256 nativa
//     url.searchParams.set("recipient", RECIPIENT);
//     url.searchParams.set("message", message.toLowerCase());

//     const res = await fetch(url.toString(), { method: "GET" });

//     if (!res.ok) throw new Error(`Across API error ${res.status}`);

//     const quote = await res.json();
//     const totalRelayFee = BigInt(quote.totalRelayFee.total);
//     const lpFee = BigInt(quote.lpFee.total);
//     const outputAmount = amountToSell - totalRelayFee - lpFee; // ≈ recomendado

//     console.log("Quote:", { totalRelayFee, lpFee, outputAmount });
//   } catch (error) {
//     console.error("Error:", error);
//     throw error;
//   }

//   function getCurrencies(tokenToSell: Address): [Address, Address] {
//     // Según las reglas de UniswapV4, currency0 siempre debe tener la dirección más pequeña
//     if (tokenToSell.toLowerCase() < USDCm.toLowerCase()) {
//       return [tokenToSell, USDCm];
//     } else {
//       return [USDCm, tokenToSell];
//     }
//   }
// }
