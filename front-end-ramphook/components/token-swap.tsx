"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ArrowUpDown, X, Loader2 } from "lucide-react";

import swapDirectlyUSDT from "@/lib/scripts/swapDirectlyUSDT";
import bridgeTokensToBase from "@/lib/scripts/bridgeTokensToBase";

interface SwapCompoProps {
  onClose?: () => void;
  chainId?: number;
  address?: string;
}

export default function SwapCompo({
  onClose,
  chainId,
  address,
}: SwapCompoProps) {
  const [selectedToken, setSelectedToken] = useState("");
  const [amountToSwap, setAmountToSwap] = useState("");
  const [minAmountToGet, setMinAmountToGet] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  const tokensTest = [
    {
      value: "0xC3726B8054f88FD63F9268c0ab21667083D01414", // USDT address on Base Sepolia
      label: "USDT to USDC",
      logo: "/tether-usdt-logo.png",
    },

    {
      value: "link",
      label: "LINK",
      logo: "/chainlink-link-logo.png",
    },
  ];
  const tokensMain = [
    {
      value: "0x6B175474E89094C44Da98b954EedeAC495271d0F", // DAI address on Mainnet
      label: "DAI to USDC",
      logo: "/dai-logo.png",
    },

    {
      value: "link",
      label: "LINK",
      logo: "/chainlink-link-logo.png",
    },
  ];

  const handleSwap = async () => {
    console.log("Swap initiated:", {
      token: selectedToken,
      amountToSwap,
      minAmountToGet,
    });

    setIsLoading(true);

    try {
      //!MVP: Only USDT to USDC swap is implemented
      if (
        chainId == 84532 &&
        selectedToken == "0xC3726B8054f88FD63F9268c0ab21667083D01414"
      ) {
        //!Here we execute a direct swap using the PoolSwapTest Router
        await swapDirectlyUSDT({
          senderAddress: address!,
          tokenToSell: selectedToken,
          amountToSell: amountToSwap,
          minimumAmountToReceive: minAmountToGet,
        });

        // Mostrar alerta de éxito
        alert("Transaction completed successfully!");

        // Cerrar modal después de la alerta
        onClose?.();
      }
    } catch (error) {
      console.error("Error in swap:", error);
      alert("Transaction failed. Please try again.");
    } finally {
      setIsLoading(false);
    }
  };
  const handleBridgeAndSwap = async () => {
    console.log("Swap initiated:", {
      token: selectedToken,
      amountToSwap,
      minAmountToGet,
    });

    setIsLoading(true);
    try {
      //!MVP: Only USDT to USDC swap is implemented
      if (
        chainId == 1 &&
        selectedToken == "0x6B175474E89094C44Da98b954EedeAC495271d0F"
      ) {
        //!Here we execute a direct swap using the PoolSwapTest Router
        await bridgeTokensToBase({
          senderAddress: address!,
          tokenToSell: selectedToken,
          amountToSell: amountToSwap,
          minimumAmountToReceive: minAmountToGet,
        });

        // Mostrar alerta de éxito
        alert("Bridge and Swap completed successfully!");

        // Cerrar modal después de la alerta
        onClose?.();
      }
    } catch (error) {
      console.error("Error in swap:", error);
      alert("Transaction failed. Please try again.");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className='absolute inset-0 z-50 flex items-center justify-center'>
      {/* Backdrop with blur effect - only covering the content area */}
      <div
        className='absolute inset-0 bg-black/30 backdrop-blur-md'
        onClick={!isLoading ? onClose : undefined}
      ></div>

      {/* Modal content */}
      <Card className='w-full max-w-md shadow-2xl relative z-10'>
        <button
          onClick={onClose}
          className='absolute top-4 right-4 p-1 rounded-full hover:bg-gray-200 transition-colors'
          aria-label='Close'
          disabled={isLoading}
        >
          <X className='h-5 w-5' />
        </button>
        {chainId == 1 && (
          <>
            <CardHeader className='text-center'>
              <CardTitle className='text-2xl font-bold flex items-center justify-center gap-2'>
                <ArrowUpDown className='h-6 w-6' />
                Token Swap
              </CardTitle>
            </CardHeader>
            <CardContent className='space-y-6'>
              <div className='space-y-2'>
                <Label htmlFor='token-select'>Select Token to Swap</Label>
                <Select value={selectedToken} onValueChange={setSelectedToken}>
                  <SelectTrigger id='token-select'>
                    <SelectValue placeholder='Choose a token' />
                  </SelectTrigger>
                  <SelectContent>
                    {tokensMain.map((token) => (
                      <SelectItem key={token.value} value={token.value}>
                        <div className='flex items-center gap-2'>
                          <img
                            src={token.logo || "/placeholder.svg"}
                            alt={`${token.label} logo`}
                            className='h-5 w-5 rounded-full'
                          />
                          <span>{token.label}</span>
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className='space-y-2'>
                <Label htmlFor='amount-swap'>Amount to Swap</Label>
                <Input
                  id='amount-swap'
                  type='number'
                  placeholder='0.00'
                  value={amountToSwap}
                  onChange={(e) => setAmountToSwap(e.target.value)}
                  className='text-right'
                  disabled={isLoading}
                />
              </div>

              <div className='space-y-2'>
                <Label htmlFor='min-amount'>Minimum Amount to Get</Label>
                <Input
                  id='min-amount'
                  type='number'
                  placeholder='0.00'
                  value={minAmountToGet}
                  onChange={(e) => setMinAmountToGet(e.target.value)}
                  className='text-right'
                  disabled={isLoading}
                />
              </div>

              <Button
                onClick={handleBridgeAndSwap}
                className='w-full h-12 text-lg font-semibold bg-gradient-to-r from-[#cb3b3d] to-gradient-1-end text-black'
                disabled={
                  !selectedToken ||
                  !amountToSwap ||
                  !minAmountToGet ||
                  isLoading
                }
              >
                {isLoading ? (
                  <>
                    <Loader2 className='mr-2 h-4 w-4 animate-spin' />
                    Processing...
                  </>
                ) : (
                  "Bridge to Base and Swap Tokens"
                )}
              </Button>
            </CardContent>
          </>
        )}
        {chainId != 1 && (
          <>
            <CardHeader className='text-center'>
              <CardTitle className='text-2xl font-bold flex items-center justify-center gap-2'>
                <ArrowUpDown className='h-6 w-6' />
                Token Swap
              </CardTitle>
            </CardHeader>
            <CardContent className='space-y-6'>
              <div className='space-y-2'>
                <Label htmlFor='token-select'>Select Token to Swap</Label>
                <Select value={selectedToken} onValueChange={setSelectedToken}>
                  <SelectTrigger id='token-select'>
                    <SelectValue placeholder='Choose a token' />
                  </SelectTrigger>
                  <SelectContent>
                    {tokensTest.map((token) => (
                      <SelectItem key={token.value} value={token.value}>
                        <div className='flex items-center gap-2'>
                          <img
                            src={token.logo || "/placeholder.svg"}
                            alt={`${token.label} logo`}
                            className='h-5 w-5 rounded-full'
                          />
                          <span>{token.label}</span>
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className='space-y-2'>
                <Label htmlFor='amount-swap'>Amount to Swap</Label>
                <Input
                  id='amount-swap'
                  type='number'
                  placeholder='0.00'
                  value={amountToSwap}
                  onChange={(e) => setAmountToSwap(e.target.value)}
                  className='text-right'
                  disabled={isLoading}
                />
              </div>

              <div className='space-y-2'>
                <Label htmlFor='min-amount'>Minimum Amount to Get</Label>
                <Input
                  id='min-amount'
                  type='number'
                  placeholder='0.00'
                  value={minAmountToGet}
                  onChange={(e) => setMinAmountToGet(e.target.value)}
                  className='text-right'
                  disabled={isLoading}
                />
              </div>

              <Button
                onClick={handleSwap}
                className='w-full h-12 text-lg font-semibold bg-gradient-to-r from-[#cb3b3d] to-gradient-1-end text-black'
                disabled={
                  !selectedToken ||
                  !amountToSwap ||
                  !minAmountToGet ||
                  isLoading
                }
              >
                {isLoading ? (
                  <>
                    <Loader2 className='mr-2 h-4 w-4 animate-spin' />
                    Processing...
                  </>
                ) : (
                  "Swap Tokens"
                )}
              </Button>
            </CardContent>
          </>
        )}
        ;
      </Card>
    </div>
  );
}
