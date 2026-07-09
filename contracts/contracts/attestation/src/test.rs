#![cfg(test)]
use crate::{DaloyAttestations, DaloyAttestationsClient};
use soroban_sdk::{testutils::Address as _, Address, Env};

#[test]
fn test_attest_and_read() {
    let env = Env::default();
    env.mock_all_auths();

    let contract_id = env.register(DaloyAttestations, ());
    let client = DaloyAttestationsClient::new(&env, &contract_id);

    let admin = Address::generate(&env);
    client.initialize(&admin);

    // Publish a day's attestation.
    client.attest(&20260708u32, &7_129_264u64, &48_542u64, &true);

    // Read it back.
    let rec = client.get_attestation(&20260708u32).unwrap();
    assert_eq!(rec.date, 20260708);
    assert_eq!(rec.usdc_volume, 7_129_264);
    assert_eq!(rec.payment_count, 48_542);
    assert_eq!(rec.is_healthy, true);

    // A date never attested returns None.
    assert!(client.get_attestation(&20260101u32).is_none());
}
