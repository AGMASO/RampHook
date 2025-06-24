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
import { ArrowDownToLine, X, Loader2 } from "lucide-react";
import onRampOrder from "@/lib/scripts/onRampOrder";

interface OnRampOrderProps {
  onClose?: () => void;
  chainId?: number;
  address?: string;
}

export default function OnRampOrder({
  onClose,
  chainId,
  address,
}: OnRampOrderProps) {
  const [selectedToken, setSelectedToken] = useState("");
  const [amountUSD, setAmountUSD] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const tokens = [
    {
      value: "0xC3726B8054f88FD63F9268c0ab21667083D01414",
      label: "USDT",
      logo: "/tether-usdt-logo.png",
    },

    {
      value: "link",
      label: "LINK",
      logo: "/chainlink-link-logo.png",
    },
  ];

  const handleOnRamp = async () => {
    console.log("On Ramp order initiated:", {
      token: selectedToken,
      amountUSD,
    });

    setIsLoading(true);

    try {
      if (
        chainId == 84532 &&
        selectedToken == "0xC3726B8054f88FD63F9268c0ab21667083D01414"
      ) {
        console.log("Executing onRampOrder for USDT on Base Sepolia");
        //!Aqui ejecutamos un swap directamten usando el PoolSwapTest Router
        await onRampOrder({
          amountToSell: amountUSD,
          receiverAddress: address!,
          desiredToken: selectedToken,
        });

        // Mostrar alerta de éxito
        alert("Transaction completed successfully!");

        // Cerrar modal después de la alerta
        onClose?.();
      }
    } catch (error) {
      console.error("Error in onRamp:", error);
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

        <CardHeader className='text-center'>
          <CardTitle className='text-2xl font-bold flex items-center justify-center gap-2'>
            <ArrowDownToLine className='h-6 w-6' />
            On Ramp Order
          </CardTitle>
        </CardHeader>
        <CardContent className='space-y-6'>
          <div className='space-y-2'>
            <Label htmlFor='amount-usd'>Amount USD to On Ramp</Label>
            <Input
              id='amount-usd'
              type='number'
              placeholder='0.00'
              value={amountUSD}
              onChange={(e) => setAmountUSD(e.target.value)}
              className='text-right'
              disabled={isLoading}
            />
          </div>
          <div className='space-y-2'>
            <Label htmlFor='token-select'>Select Token to Receive</Label>
            <Select
              value={selectedToken}
              onValueChange={setSelectedToken}
              disabled={isLoading}
            >
              <SelectTrigger id='token-select'>
                <SelectValue placeholder='Choose a token' />
              </SelectTrigger>
              <SelectContent>
                {tokens.map((token) => (
                  <SelectItem key={token.value} value={token.value}>
                    <div className='flex items-center gap-2'>
                      <img
                        src={token.logo || ""}
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

          <Button
            onClick={handleOnRamp}
            className='w-full h-12 text-lg font-semibold bg-gradient-to-r from-gradient-1-end to-[#1184B6] text-white'
            disabled={!selectedToken || !amountUSD || isLoading}
          >
            {isLoading ? (
              <>
                <Loader2 className='mr-2 h-4 w-4 animate-spin' />
                Processing...
              </>
            ) : (
              "Process On Ramp"
            )}
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
