-- Silver: deduplicated hourly price snapshots.
-- The ingest job is append-only (Sandbox forbids MERGE), so idempotency is
-- enforced here: one row per (coin, snapshot hour), latest fetch wins.

with ranked as (
    select
        coin_id,
        vs_currency,
        price,
        fetched_at,
        timestamp_trunc(fetched_at, hour) as snapshot_hour,
        row_number() over (
            partition by coin_id, vs_currency, timestamp_trunc(fetched_at, hour)
            order by fetched_at desc
        ) as rn
    from {{ source('raw_market', 'stablecoin_prices') }}
)

select
    coin_id,
    vs_currency,
    price,
    snapshot_hour,
    fetched_at
from ranked
where rn = 1
