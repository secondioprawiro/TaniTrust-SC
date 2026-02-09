/// Tani Token (TATO) - The currency for TaniTrust agricultural marketplace
module tanitrust::tani_token {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::url;

    // ==================== ONE TIME WITNESS ====================
    
    /// One-Time-Witness for the token
    public struct TANI_TOKEN has drop {}

    // ==================== STRUCTS ====================

    /// Treasury capability holder - can mint/burn tokens
    public struct TreasuryCapHolder has key, store {
        id: UID,
        treasury_cap: TreasuryCap<TANI_TOKEN>,
    }

    // ==================== INITIALIZATION ====================

    /// Initialize the Tani Token
    /// Creates the token with metadata and treasury capability
    fun init(witness: TANI_TOKEN, ctx: &mut TxContext) {
        // Create the currency with metadata
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            8, // decimals (like SUI, 8 decimals: 1 TATO = 100,000,000 units)
            b"TATO", // symbol
            b"Tani Token", // name
            b"The official currency of TaniTrust agricultural marketplace - empowering Indonesian farmers", // description
            option::some(url::new_unsafe_from_bytes(b"https://tanitrust.com/tato-logo.png")), // icon URL (you can change this)
            ctx
        );

        // Freeze the metadata object (standard practice)
        transfer::public_freeze_object(metadata);

        // Store treasury cap in a shared object so it can be accessed
        let holder = TreasuryCapHolder {
            id: object::new(ctx),
            treasury_cap,
        };
        
        transfer::share_object(holder);
    }

    // ==================== ADMIN FUNCTIONS ====================

    /// Mint new TATO tokens
    /// Only for testing/faucet purposes
    public fun mint(
        cap_holder: &mut TreasuryCapHolder,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<TANI_TOKEN> {
        coin::mint(&mut cap_holder.treasury_cap, amount, ctx)
    }

    /// Burn TATO tokens
    public fun burn(
        cap_holder: &mut TreasuryCapHolder,
        coin: Coin<TANI_TOKEN>
    ) {
        coin::burn(&mut cap_holder.treasury_cap, coin);
    }

    // ==================== FAUCET FOR TESTING ====================

    /// Faucet: Get free TATO tokens for testing
    /// Mints 1000 TATO (1,000 * 10^8 units) to the caller
    entry fun claim_faucet(
        cap_holder: &mut TreasuryCapHolder,
        ctx: &mut TxContext
    ) {
        // Mint 1000 TATO tokens (1000 * 100_000_000 units)
        let faucet_amount = 1_000 * 100_000_000; // 1000 TATO
        let faucet_coins = coin::mint(&mut cap_holder.treasury_cap, faucet_amount, ctx);
        
        // Transfer to the caller
        transfer::public_transfer(faucet_coins, tx_context::sender(ctx));
    }

    /// Faucet with custom amount (for testing different scenarios)
    entry fun claim_faucet_amount(
        cap_holder: &mut TreasuryCapHolder,
        amount: u64, // Amount in TATO (will be multiplied by 10^8)
        ctx: &mut TxContext
    ) {
        let actual_amount = amount * 100_000_000;
        let coins = coin::mint(&mut cap_holder.treasury_cap, actual_amount, ctx);
        transfer::public_transfer(coins, tx_context::sender(ctx));
    }

    // ==================== VIEW FUNCTIONS ====================

    /// Get total supply
    public fun total_supply(cap_holder: &TreasuryCapHolder): u64 {
        coin::total_supply(&cap_holder.treasury_cap)
    }

    // ==================== HELPER FUNCTIONS ====================

    /// Convert TATO to smallest units (like SUI to MIST)
    public fun tato_to_units(tato: u64): u64 {
        tato * 100_000_000
    }

    /// Convert smallest units to TATO
    public fun units_to_tato(units: u64): u64 {
        units / 100_000_000
    }

    // ==================== TEST ONLY ====================

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(TANI_TOKEN {}, ctx);
    }

    #[test_only]
    public fun mint_for_testing(
        cap_holder: &mut TreasuryCapHolder,
        amount: u64,
        ctx: &mut TxContext
    ): Coin<TANI_TOKEN> {
        coin::mint(&mut cap_holder.treasury_cap, amount, ctx)
    }
}
