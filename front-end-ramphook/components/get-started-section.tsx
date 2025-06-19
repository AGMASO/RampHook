"use client";

import { useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import Link from "next/link";
import { useAccount, useChainId } from "wagmi";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import SwapCompo from "@/components/token-swap";
import OnRampOrder from "@/components/on-ramp-order";
import SafeApiKit from "@safe-global/api-kit";
import Image from "next/image";
// import ModalAccountsAvalaible from "./ModalAccountsAvalaible";

// Use the type directly from the API response

export default function GetStartedSection() {
  const { address, isConnected, isConnecting, isDisconnected, chain } =
    useAccount();
  const [imageOpacity, setImageOpacity] = useState(1);
  const [imageZIndex, setImageZIndex] = useState(30);
  const [optionsOpacity, setOptionsOpacity] = useState(0);
  const [openModalSwaps, setOpenModalSwaps] = useState(false);
  const [openModalOnRamp, setOpenModalOnRamp] = useState(false);

  useEffect(() => {
    if (isConnected) {
      // Initial state
      setImageOpacity(1);
      setImageZIndex(30);
      setOptionsOpacity(0);

      // After 2 seconds, fade out image and show options
      const fadeTimer = setTimeout(() => {
        setImageOpacity(0);
        setOptionsOpacity(1);
        setImageZIndex(0);
      }, 2000);

      return () => clearTimeout(fadeTimer);
    }
  }, [isConnected]);

  const handleOpenModalSwaps = () => {
    setOpenModalSwaps(true);
  };

  const handleCloseModalSwaps = () => {
    setOpenModalSwaps(false);
  };

  const handleOpenModalOnRamp = () => {
    setOpenModalOnRamp(true);
  };

  const handleCloseModalOnRamp = () => {
    setOpenModalOnRamp(false);
  };

  return (
    <>
      {openModalSwaps && isConnected && (
        <SwapCompo onClose={handleCloseModalSwaps} />
      )}

      {openModalOnRamp && isConnected && (
        <OnRampOrder onClose={handleCloseModalOnRamp} />
      )}

      {isConnected && (
        <div
          className={`relative w-full h-full min-h-[400px] flex items-center justify-center ${
            openModalSwaps || openModalOnRamp ? "opacity-50" : ""
          }`}
        >
          <div
            className='absolute inset-0 flex items-center justify-center transition-all duration-1000 ease-in-out'
            style={{
              opacity: imageOpacity,
              zIndex: imageZIndex,
            }}
          >
            <Image
              src='/matrix-pills.png'
              alt='Choose your path'
              width={700}
              height={500}
              className='rounded-xl shadow-2xl'
              priority
            />
          </div>

          <div
            className='flex flex-row gap-20 items-center justify-between relative z-5 transition-all duration-1000 ease-in-out'
            style={{ opacity: optionsOpacity }}
          >
            <div className='flex flex-col items-center justify-center p-12 bg-gradient-to-r from-[#b13739] to-gradient-1-end h-fit min-h-[300px] min-w-[350px] rounded-xl transition-all duration-1000 ease-in-out hover:scale-105 hover:shadow-lg'>
              <div className='flex flex-col items-center max-w-md'>
                <h2 className='text-2xl font-bold mb-4 text-center font-extrabold'>
                  SWAP TOKENS
                </h2>

                <div className='space-y-4 w-full flex flex-col gap-1'>
                  <Button
                    className='w-full bg-black text-white hover:bg-gray-800 hover:scale-105 transition-all duration-300 ease-in-out'
                    onClick={handleOpenModalSwaps}
                  >
                    Start a swap
                  </Button>
                </div>
              </div>
            </div>
            <div className='flex flex-col items-center justify-center p-12 bg-gradient-to-r from-gradient-1-end to-[#1184B6] h-fit min-h-[300px] min-w-[350px] rounded-xl transition-all duration-1000 ease-in-out hover:scale-105 hover:shadow-lg'>
              <div className='flex flex-col items-center max-w-md'>
                <h2 className='text-2xl font-bold mb-4 text-center font-montserrat-extrabold'>
                  ON RAMP ORDER
                </h2>

                <div className='space-y-4 w-full flex flex-col gap-1'>
                  <Button
                    className='w-full bg-black text-white hover:bg-gray-800 hover:scale-105 transition-all duration-300 ease-in-out'
                    onClick={handleOpenModalOnRamp}
                  >
                    Start an order
                  </Button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {!isConnected && (
        <div className='flex flex-col items-center justify-center p-12 bg-gradient-to-r from-[#1184B6] to-gradient-1-end h-fit min-h-[60vh] min-w-[60vw] rounded-xl transition-all duration-1000 ease-in-out'>
          <div className='flex flex-col items-center max-w-md'>
            <p className='text-center mb-6'>
              Connect your wallet to create a new Safe Account or open an
              existing one
            </p>
            <ConnectButton />
          </div>
        </div>
      )}
    </>
  );
}
