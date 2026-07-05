-- Gold: one row per day. Dashboard reads THIS tiny table, never Hubble,
-- keeping Looker Studio refreshes near-zero-cost.

select
    payment_date,
    count(*)                                        as payment_count,
    sum(amount)                                     as total_usdc_volume,
    count(distinct from_account)                    as unique_senders,
    count(distinct to_account)                      as unique_receivers,
    countif(operation_type in (2, 13))              as path_payment_count,  -- cross-currency (remittance-style) ops
    sum(if(operation_type in (2, 13), amount, 0))   as path_payment_volume,
    approx_quantiles(amount, 100)[offset(50)]       as median_payment_usdc
from {{ ref('stg_stellar__usdc_payments') }}
group by payment_date
