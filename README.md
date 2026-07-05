# Daloy 🌊

**Stablecoin Flow Intelligence for Philippine Remittance Corridors on Stellar.**
*"Daloy" is Filipino for "flow."*

An open, zero-cost analytics pipeline tracking USDC flows, path payments
(the mechanism behind cross-currency remittances), and stablecoin peg health
on the Stellar network — built entirely on free tiers from the Philippines.

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
│ BigQuery Sandbox (daloy project)                │
│  staging/  stg_stellar__usdc_payments   (silver)│
│            stg_market__stablecoin_prices        │
│  marts/    fct_usdc_flows_daily         (gold)  │
│            fct_depeg_monitor                    │
│  — modeled with dbt Core, tested, built daily   │
└───────────────────────┬─────────────────────────┘
                        ▼
              Looker Studio dashboard
```

## Why this design (interview answers, pre-written)

- **Bronze layer is outsourced.** SDF maintains `crypto-stellar.crypto_stellar`
  (Hubble) as a public dataset; we pay zero storage and only scan bytes.
- **No incremental models — on purpose.** BigQuery Sandbox forbids DML
  (MERGE/INSERT), so idempotency is enforced at the transform layer:
  full-refresh tables over a bounded `lookback_days` window, and ROW_NUMBER
  dedup for the append-only price feed.
- **Cost engineering.** Staging models materialize as *tables* so Hubble is
  scanned once per day; the dashboard only reads tiny gold tables.
  `maximum_bytes_billed: 20 GB` acts as a per-query circuit breaker inside
  the 1 TB/month free quota. Partition (`batch_run_date`) and column pruning
  on `enriched_history_operations` (one of Hubble's widest tables).
- **Ledger sequence + `closed_at` are natural watermarks** — no synthetic
  bookkeeping needed for late-arriving data.

## Stack

BigQuery (Sandbox, ₱0) · dbt Core · Python (google-cloud-bigquery, requests)
· GitHub Actions (free cron) · Looker Studio (free)

## Setup

1. Create a BigQuery Sandbox project (no credit card): console.cloud.google.com/bigquery
2. `gcloud auth application-default login`
3. `cp dbt/profiles.yml.example ~/.dbt/profiles.yml` and set your project id
4. `export GCP_PROJECT_ID=your-project && python ingestion/ingest_market_data.py`
5. `cd dbt && dbt deps && dbt build`
6. Connect Looker Studio to the `daloy_marts` dataset

For CI: add repo secrets `GCP_PROJECT_ID` and `GCP_SA_KEY`
(a service-account JSON key with BigQuery Data Editor + Job User roles).

## Known limitations

- Sandbox tables expire after 60 days (fine for hackathon scope; upgrade
  path: enable billing → switch staging models to incremental MERGE).
- Hubble updates daily, so "near-real-time" is D-1; the Horizon API polling
  layer is the post-hackathon roadmap item.
- USDC issuer address is pinned in `dbt_project.yml` vars — verify against
  stellar.expert.
