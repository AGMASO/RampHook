# RAMPHOOK


First of all, thank you in advance for your time.

Below is the structure of my project in version 1 — the simplest version I need in order to begin iterating and adding more features:

![alt text](<../public/Screenshot 2025-06-13 at 15.55.38.png>)

## Goal
The goal is to create orders inside the Hook, using my USDC liquidity and bypass the Uniswap v4 swap logic when a Swapper matches an order created by my Hook.

If no order is matched, then the Swapper proceeds with a normal swap using the liquidity in the Pool and PoolManager as usual.

## Problems of understanding:

1. I was assuming that by inverting the signs in the beforeSwapDelta (compared to SwapParams), we could block the swap from happening in the PoolManager. Is that correct?

2. In the case of a CoW (Coincidence of Wants), I’m confused about when and how the token transfers between USER1 and USER2 should occur. Should this happen inside the beforeSwap() Hook?
Here?

![alt text](<../public/Screenshot 2025-06-13 at 17.13.21.png>)


## Errors 

1. I'm getting a CurrencyNotSettled() error when an order match occurs.
I understand the error — it sends USDC (fake ERC20) to USER2, but the transaction reverts because the currency is not settled or the user does not have the right to receive that amount.

2. I encounter an underflow/overflow issue during a normal swap when USER2 is supposed to transfer USDC tokens to the PoolManager.
This happens because USER2 doesn't hold any USDC (fake ERC20) tokens.

3. I encounter StackTooDeep errors. It doesn't allow me to use more local variables. I guess is becuase imports? how do i avoid that? 

![alt text](<../public/Screenshot 2025-06-13 at 16.46.59.png>)

![alt text](<../public/Screenshot 2025-06-13 at 17.21.18.png>)