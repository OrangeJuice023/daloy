# Daloy 🌊

**Stablecoin Flow Intelligence for Philippine Remittance Corridors on Stellar.**
*"Daloy" is Filipino for "flow."*

Daloy is an open, zero-cost intelligence layer that makes stablecoin remittance
flows on Stellar visible — so builders, senders, and regulators can finally see
the rails Filipino families depend on. It tracks USDC flow volume, path payments
(the on-chain mechanism behind cross-currency remittances), and stablecoin peg
health, all through a production-grade data pipeline built entirely on free tiers
from the Philippines.

**Smart contract (Stellar testnet):** `CCQR6OJVMRLKAT7SMBJK2ZGYGWXLJNO2RIYOP3XEKI2EK45Y26TP3T3M`
[View on stellar.expert →](https://stellar.expert/explorer/testnet/contract/CCQR6OJVMRLKAT7SMBJK2ZGYGWXLJNO2RIYOP3XEKI2EK45Y26TP3T3M)
---

## The problem

The Philippines received a record **$35.63 billion** in OFW cash remittances in
2025 (7.3% of GDP, per Bangko Sentral ng Pilipinas), and families still lose a
meaningful percentage to transfer fees. As of 2026, a new **1% US remittance tax**
adds further cost pressure on the ~40% of remittances that flow from the United
States. Stablecoins on Stellar offer a cheaper rail — but the ecosystem is a black
box: no accessible way to see corridor volumes, how much activity is genuinely
cross-currency, whether the stablecoin holds its $1 peg, or whether transaction
patterns look anomalous. Institutional blockchain analytics tools are
enterprise-priced and don't focus on Stellar's PH corridors. Without visibility,
builders can't find underserved corridors, and users can't trust the rails.

## What Daloy does

An ELT pipeline that ingests Stellar's public on-chain data plus market data,
models it through a medallion architecture in BigQuery with dbt, and serves a
public dashboard — plus an on-chain attestation contract that publishes verifiable
flow-health summaries to Stellar, making Daloy composable infrastructure rather
than a closed app.

## Architecture

```
┌─────────────────────────┐   ┌──────────────────┐
│ Hubble (Stellar public  │   │ CoinGecko API    │
│ BigQuery dataset — the  │   │ (hourly ingest,  │
│ bronze layer, free)     │   │ GitHub Actions)  │
└───────────┬─────────────┘   └────────┬─────────┘
            │                          │  batch load job
            ▼                          ▼
┌─────────────────────────────────────────────────┐
│ BigQuery Sandbox (daloy-hackathon project)      │
│  staging/  stg_stellar__usdc_payments   (silver)│
│            stg_market__stablecoin_prices        │
│  marts/    fct_usdc_flows_daily         (gold)  │
│            fct_depeg_monitor                    │
│  — modeled with dbt Core, tested, built daily   │
└──────────────┬──────────────────────┬───────────┘
               ▼                      ▼
     Looker Studio dashboard   Soroban attestation
                               contract (testnet)
```

## Engineering decisions (a.k.a. what building this actually taught me)

These are the real problems hit while building, and how each was diagnosed and
fixed. They double as the "why" behind the design.

### 1. Asset identity: the $8.8 trillion that wasn't real
A naive filter on `asset_code = 'USDC'` returned roughly **$8.8 trillion of daily
volume** — obviously wrong. The cause: on Stellar, *anyone* can issue an asset
called "USDC." Asset identity is **code + issuer**, never code alone. The feed was
summing Circle's real USDC together with every scam/test token wearing the same
name. Pinning Circle's verified issuer
(`GA5ZSEJYB37JRC5AVCIA5MOP4RHTM335X2KGX3IHOJAPP5RE34K4KZVN`) dropped the number to
a plausible **~$778M/day** — removing ~5% of operations but ~99.99% of the fake
"volume." Lesson: never trust an ambiguous identifier; verify against the real
asset registry.

### 2. Cost engineering: the 71 GB query the guardrail caught
A 30-day scan of Hubble's `enriched_history_operations` (one of its widest tables)
wanted to bill **71 GB** — and a `maximum_bytes_billed` circuit breaker configured
*before the first build* rejected it. The math that mattered: at ~2.4 GB/day, a
daily CI rebuild scanning 30 days = **~2.1 TB/month, double the 1 TB free quota.**
The fix wasn't raising the limit to whatever the query wanted — it was resizing
the scan window to **14 days (~530 GB/month)** and keeping the guardrail as a
per-query safety net. Partition pruning on `batch_run_date` and column pruning do
the rest. Cost control as a design constraint, not an afterthought.

### 3. Schema drift & type mismatches: verify against the live schema
Two failures traced to assuming column details instead of checking:
- `batch_run_date` is a **DATETIME**, not a TIMESTAMP, so it couldn't be compared
  against `TIMESTAMP_SUB(CURRENT_TIMESTAMP(), ...)`. Fixed with `DATETIME_SUB`.
- The operation-ID column is **`op_id`**, not `id`, in the modeled dataset.
Both were caught by querying `INFORMATION_SCHEMA.COLUMNS` against the live table
rather than guessing name-by-name. Verify schemas; don't assume them.

### 4. Statistics on thin data: don't cry wolf while the baseline warms up
The peg monitor's z-score anomaly flag initially fired on stablecoins sitting
within **0.1%** of peg — perfectly healthy. Cause: with only a few days of hourly
snapshots, the trailing-7-day rolling stddev is tiny, so a routine wiggle computes
as a 7-sigma "outlier." The fix hardens `is_anomaly` to require **both** a
statistical outlier (|z| > 3) **and** an economically meaningful move
(> 0.2% off peg) **and** a minimum sample size, and exposes `sample_size` in the
output so the monitor's confidence is visible. Statistical significance without
economic significance is noise.

## Why this design holds up

- **Bronze layer is outsourced.** SDF maintains Hubble as a public BigQuery
  dataset; Daloy pays zero storage and only scans bytes.
- **No incremental models — on purpose.** BigQuery Sandbox forbids DML
  (MERGE/INSERT), so idempotency lives in the transform layer: bounded
  full-refresh tables + ROW_NUMBER dedup for the append-only price feed.
  *(Upgrade path documented below: enable billing → incremental MERGE.)*
- **Gold tables are tiny**, so the dashboard and attestation contract read cheap
  aggregates, never raw Hubble.
- **Ledger sequence + `closed_at` are natural watermarks** for late-arriving data.

## Stellar integration

- **Hubble** (`crypto-stellar.crypto_stellar_dbt`) — primary historical source;
  `enriched_history_operations` for payment + path-payment flows.
- **Path payments** (op types 2 & 13) — isolated as the cross-currency slice,
  i.e. the actual remittance mechanism where one asset converts to another
  mid-flight via Stellar's DEX.
- **USDC on Stellar** — Circle's verified issuer, tracked for flow and peg health.
- **Soroban attestation contract** — publishes verifiable daily flow-health
  summaries on-chain, making Daloy's output composable by other builders.
  <!-- TODO: expand once contract is deployed -->

## Stack

BigQuery (Sandbox, ₱0) · dbt Core · Python (google-cloud-bigquery, requests)
· GitHub Actions (free cron) · Looker Studio (free) · Soroban / Rust (testnet)

## Findings surfaced by the pipeline

- **Whale-flow regime (late Jun–early Jul):** several consecutive days at
  $600M–750M vs a ~$10M–140M baseline — large treasury-scale movement.
- **Micro-payment swarm:** one day showed **thousands of path payments** moving
  almost no value (median payment near the floor) — likely bots or a stress
  test. A *count*-based anomaly view catches this where a volume-based one misses
  it entirely.

## Setup

1. Create a BigQuery Sandbox project (no credit card): console.cloud.google.com/bigquery
2. `gcloud auth application-default login`
3. `cp dbt/profiles.yml.example ~/.dbt/profiles.yml` and set your project id
4. `export GCP_PROJECT_ID=your-project && python ingestion/ingest_market_data.py`
5. `cd dbt && dbt deps && dbt build`
6. Connect Looker Studio to the `daloy_marts` dataset

For CI: add repo secrets `GCP_PROJECT_ID` and `GCP_SA_KEY` (a service-account JSON
key with BigQuery Data Editor + Job User roles). Two scheduled workflows run the
hourly ingest and the daily dbt build.

## Known limitations

- Sandbox tables expire after 60 days (fine for hackathon scope; upgrade path:
  enable billing → switch staging models to incremental MERGE).
- Hubble updates daily, so freshness is D-1; a live Horizon polling layer is a
  roadmap item.
- Window edges (first/last day of the rolling window) are partial by nature.
- The z-score baseline needs ~7 days of hourly snapshots to reach full
  sensitivity; `sample_size` in `fct_depeg_monitor` surfaces this.

---

*Built solo for the APAC Stellar Hackathon (DeFi & Ecosystem Composability track)
by a student from the University of the Philippines, Manila. 🇵🇭*
