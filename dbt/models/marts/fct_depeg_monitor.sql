-- Gold: hourly stablecoin peg health. Flags deviation > 0.5% from $1 and
-- statistical outliers (|z| > 3 vs trailing 7-day window) — the lightweight
-- "fraud/anomaly signal" layer.

with prices as (
    select
        coin_id,
        snapshot_hour,
        price
    from {{ ref('stg_market__stablecoin_prices') }}
    where vs_currency = 'usd'
),

stats as (
    select
        *,
        avg(price) over w    as rolling_avg,
        stddev(price) over w as rolling_stddev
    from prices
    window w as (
        partition by coin_id
        order by unix_seconds(timestamp(snapshot_hour))
        range between 604800 preceding and 1 preceding  -- trailing 7 days
    )
)

select
    coin_id,
    snapshot_hour,
    price,
    abs(price - 1.0)                     as peg_deviation,
    abs(price - 1.0) > 0.005             as is_depeg_alert,
    safe_divide(price - rolling_avg, nullif(rolling_stddev, 0)) as z_score,
    abs(safe_divide(price - rolling_avg, nullif(rolling_stddev, 0))) > 3 as is_anomaly
from stats
