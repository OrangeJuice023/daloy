-- Gold: hourly stablecoin peg health, one row per (coin, snapshot_hour).
-- Two independent flags:
--   is_depeg_alert — economic: price is >0.5% off $1 (a real peg event)
--   is_anomaly     — statistical AND economic: |z|>3 vs trailing 7-day window
--                    AND the move is at least 0.2% (see floor rationale below)
-- Dashboard reads this tiny table directly.

with prices as (
    select
        coin_id,
        snapshot_hour,
        price
    from {{ ref('stg_market__stablecoin_prices') }}
    where vs_currency = 'usd'   -- PHP rows excluded here so peg math stays in $ terms
),

stats as (
    select
        coin_id,
        snapshot_hour,
        price,
        avg(price)   over w as rolling_avg,
        stddev(price) over w as rolling_stddev,
        -- How many prior points the rolling window actually saw. Early in the
        -- monitor's life this is small, which is WHY the anomaly floor exists.
        count(price) over w as sample_size
    from prices
    window w as (
        partition by coin_id
        order by unix_seconds(timestamp(snapshot_hour))
        range between 604800 preceding and 1 preceding  -- trailing 7 days, excl. current row
    )
),

scored as (
    select
        *,
        abs(price - 1.0) as peg_deviation,
        safe_divide(price - rolling_avg, nullif(rolling_stddev, 0)) as z_score
    from stats
)

select
    coin_id,
    snapshot_hour,
    price,
    peg_deviation,
    z_score,
    sample_size,

    -- Economic peg event: distance from $1 alone, no statistics involved.
    peg_deviation > 0.005 as is_depeg_alert,

    -- Anomaly requires BOTH a statistical outlier AND an economically
    -- meaningful move. On a short rolling window the stddev is tiny, so a
    -- routine 0.1% wiggle can compute as a 7-sigma "outlier" -- false alarms.
    -- The 0.002 (0.2%) floor suppresses that until the 7-day baseline fills
    -- in (~Jul 12). Also require sample_size >= 24 so we never flag on a
    -- near-empty window. Remove these guards only if you want pure-statistical
    -- flags back and understand they will be noisy on short history.
    (
        abs(z_score) > 3
        and peg_deviation > 0.002
        and sample_size >= 24
    ) as is_anomaly

from scored