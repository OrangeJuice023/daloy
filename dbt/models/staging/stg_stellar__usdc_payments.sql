-- Silver: successful USDC payment + path-payment operations, last N days.
-- Cost control: filter the batch_run_date partition AND select only needed
-- columns — enriched_history_operations is one of Hubble's widest tables.
-- Op types: 1 = payment, 2 = path_payment_strict_receive, 13 = path_payment_strict_send.

select
    id                        as operation_id,
    transaction_hash,
    ledger_sequence,
    closed_at,
    date(closed_at)           as payment_date,
    type                      as operation_type,
    `from`                    as from_account,
    `to`                      as to_account,
    amount,
    asset_code,
    asset_issuer
from {{ source('hubble', 'enriched_history_operations') }}
where batch_run_date >= timestamp_sub(current_timestamp(), interval {{ var('lookback_days') }} day)
  and closed_at      >= timestamp_sub(current_timestamp(), interval {{ var('lookback_days') }} day)
  and type in (1, 2, 13)
  and asset_code = 'USDC'
  and asset_issuer = '{{ var("usdc_issuer") }}'
  and (successful = true or successful is null)
  and `from` != `to`  -- exclude self-transfers / arbitrage loops
