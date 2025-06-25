import { Shield, Lock, Wallet, Medal } from "lucide-react";
import React from "react";

const Features = () => {
  return (
    <main className='container mx-auto flex-1 flex flex-col items-center justify-center text-center px-4 py-20'>
      <div className='flex flex-col items-center justify-center'>
        <h2 className='text-4xl font-bold text-white'>
          RampHook, a DEX-Based On-Ramp System
        </h2>
        <p className='text-gray-300 text-center text-xl max-w-2xl pt-4'>
          On-ramp users only need to deposit USD to receive any token tehy want
          listed on Uniswap V4. Their swaps are always fee-free when matched.
          <br />
          <br />
          Swappers user can get also free fee swaps if they match an onramper
          order.
          <br />
          <br />
          LPs can earn high fees when a hybrid swap is executed, they receive a
          6% fee.
        </p>
      </div>
      <div className='mt-20 grid grid-cols-1 md:grid-cols-3 gap-8 w-full max-w-4xl'>
        <div className='bg-[#003856]/80 backdrop-blur-sm p-6 rounded-xl border border-[#1184B6]/20 flex flex-col items-center hover:bg-[#003856]/90 transition-colors duration-300'>
          <div className='h-12 w-12 rounded-full bg-[#1184B6]/20 flex items-center justify-center mb-4'>
            <Shield className='h-6 w-6 text-[#1184B6]' />
          </div>
          <h3 className='text-xl font-semibold text-white'>Dex Based</h3>
          <p className='mt-2 text-gray-300 text-center'>
            We use Uniswap V4 and Hooks to ensure secure and efficient swaps
          </p>
        </div>
        <div className='bg-[#003856]/80 backdrop-blur-sm p-6 rounded-xl border border-[#1184B6]/20 flex flex-col items-center hover:bg-[#003856]/90 transition-colors duration-300'>
          <div className='h-12 w-12 rounded-full bg-[#1184B6]/20 flex items-center justify-center mb-4'>
            <Medal className='h-6 w-6 text-[#1184B6]' />
          </div>
          <h3 className='text-xl font-semibold text-white'>Convinient</h3>
          <p className='mt-2 text-gray-300 text-center'>
            Onramp services only need to hold one source of asset, USDC but can
            give any token to the onramper user
          </p>
        </div>
        <div className='bg-[#003856]/80 backdrop-blur-sm p-6 rounded-xl border border-[#1184B6]/20 flex flex-col items-center hover:bg-[#003856]/90 transition-colors duration-300'>
          <div className='h-12 w-12 rounded-full bg-[#1184B6]/20 flex items-center justify-center mb-4'>
            <Wallet className='h-6 w-6 text-[#1184B6]' />
          </div>
          <h3 className='text-xl font-semibold text-white'>Tokenomics</h3>
          <p className='mt-2 text-gray-300 text-center'>
            We incentivize liquidity providers with high fees for Hybrid swaps,
            ensuring a win-win for all parties involved.
          </p>
        </div>
      </div>
    </main>
  );
};

export default Features;
