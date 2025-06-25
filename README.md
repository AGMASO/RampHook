# Ramphook

## What is Ramphook?

**Ramphook** is an innovative on-ramping service that leverages **Uniswap v4** and **Hooks** to serve users efficiently. Unlike traditional on-ramping services, our protocol only needs to maintain **a single liquidity token: USDC**, while still providing access to *any token* listed on Uniswap v4 — as long as there's a `TokenA/USDC` pool using our Hook.

---
**VIDEO DEMO**: https://youtu.be/cgY85TT_C9M

## Problem It Solves

Traditional on-ramping services must hold reserves of many different tokens to meet user demand. This creates complex, costly liquidity management and exposure risks.

Ramphook solves this by relying solely on USDC for liquidity, while still enabling access to any token listed on Uniswap v4 as long as a TokenX/USDC pool exists and is connected to our custom Hook.

Moreover, our model creates win-win incentives for all participants: onramper users, LPs, and swapper users.

1. While we use Uniswap v4 to perform swaps, **onramper users never pay any on-chain fee** — they always get a direct P2P execution.  
   *(Note: An off-chain service fee could be applied if desired.)*

2. LPs can earn **up to 6% in fees** on hybrid swap orders.

3. Swapper users may receive **zero-fee swaps** when perfectly matching an onramp order.

---

## 🔐 System Architecture

### Off-chain Phase

- The user sends a **fiat USD payment** to a bank account associated with our service.
- Once the payment is verified, the **on-chain phase** begins.
- The backend, which holds the private key of the Vault owner, creates the on-chain order on behalf of the user.

### On-chain Phase

- The **Vault**, which holds the USDC, calls the `createOnRampOrder` function in our Hook contract.
- The Hook uses `settleAndTake` logic to:
  - Mint `ClaimTokens` representing the onramp order.
  - Transfer real USDC tokens to the core pool manager in Uniswap v4.

---

## ⚙️ Coincidence of Wants (CoW): Our Second Big Innovation

When a swapper user interacts with our `TokenA/USDC` pool, one of three possible outcomes can occur:

1. **No matching onramp order found**, or the swapper's order is too small:
   - A **standard Uniswap core swap** is executed.
   - A **0.5% fee** is paid to the LPs.

2. **Perfect match with an onramp order**:
   - The Uniswap core is **bypassed entirely**.
   - A **direct P2P swap is executed with 0% fee**.

3. **Swapper's order exceeds the onramp order**:
   - A **hybrid order** is created:
     - The matching portion is P2P (0% fee).
     - The remainder is routed to the Uniswap core with a **6% fee**, incentivizing LP participation.

> **MVP Note:** Fees are intentionally exaggerated in this version to clearly showcase the mechanics: `0.5%` for normal swaps and `6%` for hybrid swaps. These will be optimized for production.

---

## Integration with **Across Protocol**

To expand the accessibility of our service, we’ve integrated **Across Protocol** as a bridging solution.  
This allows users holding tokens on **Ethereum Mainnet** to interact with our pools on **Base** seamlessly.

### Example:

1. A user wants to sell DAI for USDC, but their DAI is on Ethereum Mainnet.
2. Across automatically bridges the DAI to Base.
3. The swap executes in our pool using the Hook logic.
4. The user receives USDC directly on Base Mainnet.

---

##  Future Improvements & Product Evolution

1. **Off-chain module** to:
   - Verify fiat deposits.
   - Automate `createOnRampOrder` once payment is confirmed.

2. **Off-chain Vault rebalancing system**:
   - Sync the amount of USDC in the Vault with the fiat funds held in our bank account.
   - Automatically convert fiat to USDC and replenish the Vault when needed.

3. Implement **Off-ramping system** (crypto → fiat).

4. Enable **reverse bridging with Across**:
   - Return the final token to the user’s original network post-swap.

5. **🚀 Highly Scalable via New Pools**

   Our architecture allows seamless addition of new `TokenX/USDC` pools on Uniswap v4.  
   It’s a highly scalable solution: **the more LPs join and believe in the protocol, the more token options we can offer for on-ramping**.  
   Any token with an active community can become part of the Ramphook ecosystem simply by adding liquidity!
   
<img width="1265" alt="Screenshot 2025-06-25 at 20 25 32" src="https://github.com/user-attachments/assets/1bde46f5-61d3-4fd7-878b-74baefd6ed14" />

