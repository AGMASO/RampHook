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
import { ArrowUpDown, X } from "lucide-react";

interface SwapCompoProps {
  onClose?: () => void;
}

export default function SwapCompo({ onClose }: SwapCompoProps) {
  const [selectedToken, setSelectedToken] = useState("");
  const [amountToSwap, setAmountToSwap] = useState("");
  const [minAmountToGet, setMinAmountToGet] = useState("");

  const handleSwap = () => {
    console.log("Swap initiated:", {
      token: selectedToken,
      amountToSwap,
      minAmountToGet,
    });
  };

  const tokens = [
    {
      value: "usdt",
      label: "USDT",
      logo: "/placeholder.svg?height=24&width=24",
    },
    {
      value: "tokena",
      label: "TokenA",
      logo: "/placeholder.svg?height=24&width=24",
    },
    {
      value: "link",
      label: "LINK",
      logo: "/placeholder.svg?height=24&width=24",
    },
  ];

  return (
    <div className='absolute inset-0 z-50 flex items-center justify-center'>
      {/* Backdrop with blur effect - only covering the content area */}
      <div
        className='absolute inset-0 bg-black/30 backdrop-blur-md'
        onClick={onClose}
      ></div>

      {/* Modal content */}
      <Card className='w-full max-w-md shadow-2xl relative z-10'>
        <button
          onClick={onClose}
          className='absolute top-4 right-4 p-1 rounded-full hover:bg-gray-200 transition-colors'
          aria-label='Close'
        >
          <X className='h-5 w-5' />
        </button>

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
                {tokens.map((token) => (
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
            />
          </div>

          <Button
            onClick={handleSwap}
            className='w-full h-12 text-lg font-semibold bg-gradient-to-r from-[#cb3b3d] to-gradient-1-end text-black'
            disabled={!selectedToken || !amountToSwap || !minAmountToGet}
          >
            Swap Tokens
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
