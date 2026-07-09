#![no_std]
use soroban_sdk::{contract, contractimpl, contracttype, Address, Env, Symbol, symbol_short};

// Storage keys (instance storage: small, global contract config/data).
const ADMIN: Symbol = symbol_short!("ADMIN");

// Per-day attestation record. `date` is an integer key like 20260708 (YYYYMMDD)
// so lookups are cheap integer keys, not strings.
#[contracttype]
#[derive(Clone)]
pub struct Attestation {
    pub date: u32,          // YYYYMMDD, e.g. 20260708
    pub usdc_volume: u64,   // whole USDC (dollars), from Daloy's gold table
    pub payment_count: u64, // number of payments that day
    pub is_healthy: bool,   // peg held + no anomalies flagged
}

// Persistent storage keyed by date, so records live indefinitely.
#[contracttype]
#[derive(Clone)]
pub enum DataKey {
    Record(u32), // Record(date)
}

#[contract]
pub struct DaloyAttestations;

#[contractimpl]
impl DaloyAttestations {
    // Set the admin once. Only the admin may publish attestations.
    // Guards against re-initialization.
    pub fn initialize(env: Env, admin: Address) {
        if env.storage().instance().has(&ADMIN) {
            panic!("already initialized");
        }
        env.storage().instance().set(&ADMIN, &admin);
    }

    // Publish (or overwrite) a day's flow-health attestation on-chain.
    // Requires the admin's authorization — Daloy's pipeline signs this.
    pub fn attest(
        env: Env,
        date: u32,
        usdc_volume: u64,
        payment_count: u64,
        is_healthy: bool,
    ) {
        let admin: Address = env.storage().instance().get(&ADMIN).unwrap();
        admin.require_auth();

        let record = Attestation {
            date,
            usdc_volume,
            payment_count,
            is_healthy,
        };
        env.storage()
            .persistent()
            .set(&DataKey::Record(date), &record);
    }

    // Read back a day's attestation. Anyone can call this — it's public,
    // verifiable data. Returns None if that date was never attested.
    pub fn get_attestation(env: Env, date: u32) -> Option<Attestation> {
        env.storage().persistent().get(&DataKey::Record(date))
    }

    // Return the configured admin (who is allowed to attest).
    pub fn admin(env: Env) -> Address {
        env.storage().instance().get(&ADMIN).unwrap()
    }
}

mod test;
