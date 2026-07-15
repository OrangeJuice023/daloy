# Daloy — Hackathon Submission

**APAC Stellar Hackathon · DeFi & Ecosystem Composability track**
Solo submission · Manila, Philippines 🇵🇭

---

## Project Name
**Daloy** — Stablecoin Flow Intelligence for Philippine Remittance Corridors on Stellar.
*("Daloy" is Filipino for "flow.")*

## Problem Statement
The Philippines received a record **$35.63 billion** in OFW cash remittances in 2025
(7.3% of GDP, per Bangko Sentral ng Pilipinas), and families still lose a meaningful
percentage to transfer fees. As of 2026, a new 1% US remittance tax adds pressure on
the ~40% of remittances flowing from the United States. Stablecoins on Stellar offer a
cheaper rail — but the ecosystem is a black box: no accessible way to see corridor
volumes, how much activity is genuinely cross-currency, whether the stablecoin holds
its $1 peg, or whether transaction patterns look anomalous. Institutional blockchain
analytics are enterprise-priced and don't cover Stellar's PH corridors. Without
visibility, builders can't find underserved corridors and users can't trust the rails.

## Proposed Solution
Daloy is an open, zero-cost intelligence layer for stablecoin flows on Stellar. A
production-grade ELT pipeline ingests Stellar's public Hubble dataset plus market data,
models it through a medallion architecture (bronze → silver → gold) in BigQuery with
dbt, and serves a public dashboard tracking USDC flow volume, path payments (the
cross-currency remittance mechanism), and stablecoin peg health with statistical
anomaly detection. A deployed Soroban attestation contract publishes daily flow-health
records on-chain, so anyone can independently verify Daloy's numbers — making Daloy
composable infrastructure rather than a closed app. The entire stack runs on free tiers.

## Target Users / Audience
1. Filipino fintech builders and Stellar anchor operators who need corridor and
   liquidity intelligence to decide where to launch or expand.
2. OFW-focused remittance services comparing rail cost and reliability.
3. Researchers, journalists, and policymakers tracking stablecoin adoption in PH.
4. The Stellar developer ecosystem, which can compose on Daloy's open dbt models,
   gold tables, and on-chain attestations.

## Team Members & Roles
Gervi Paulo Corado — solo builder (data & analytics engineering, dbt/BigQuery
modeling, dashboard, Soroban contract). University of the Philippines.

## Expected / Actual Stellar Integration
- **Hubble** (`crypto-stellar.crypto_stellar_dbt`) — primary historical source;
  `enriched_history_operations` for payment and path-payment flows.
- **Path payments** (op types 2 & 13) — isolated as the cross-currency slice, the
  actual remittance mechanism where one asset converts to another via Stellar's DEX.
- **USDC on Stellar** — Circle's verified issuer, tracked for flow and peg health.
- **Soroban smart contract** — deployed to testnet, publishes verifiable daily
  flow-health attestations on-chain (contract address below).

## Track
DeFi & Ecosystem Composability

---

## Submission links
- **GitHub repository:** https://github.com/OrangeJuice023/daloy
- **Live dashboard:** <!-- paste PUBLIC Looker Studio link (test in incognito first) -->
- **Video demo:** <!-- paste video link -->
- **Presentation (PPT):** <!-- paste deck link -->

## Smart contract (Stellar testnet)
**Contract address:** `CCQR6OJVMRLKAT7SMBJK2ZGYGWXLJNO2RIYOP3XEKI2EK45Y26TP3T3M`
**Explorer:** https://stellar.expert/explorer/testnet/contract/CCQR6OJVMRLKAT7SMBJK2ZGYGWXLJNO2RIYOP3XEKI2EK45Y26TP3T3M

Live example — Daloy's real Jul 5 flow data, written to and read back from Stellar:
`{ "date": 20260705, "usdc_volume": 7129264, "payment_count": 48542, "is_healthy": true }`

## Tech stack
BigQuery (Sandbox) · dbt Core · Python · GitHub Actions (scheduled CI) ·
Looker Studio · Soroban / Rust (Stellar testnet). Total infrastructure cost: ₱0.
