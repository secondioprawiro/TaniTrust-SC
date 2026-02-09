#[test_only]
module tanitrust::marketplace_tato_tests {
    use tanitrust::marketplace::{Self, Product, Order, Dispute};
    use tanitrust::tani_token::{Self, TANI_TOKEN, TreasuryCapHolder};
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use std::string;

    // Test addresses
    const ADMIN: address = @0xAD;
    const FARMER: address = @0xFA;
    const BUYER: address = @0xB1;
    const RANDOM: address = @0x99;

    // Helper constants (prices in TATO smallest units)
    const PRODUCT_PRICE: u64 = 50_000_000; // 0.5 TATO per unit
    const PRODUCT_STOCK: u64 = 1000;
    const ORDER_QUANTITY: u64 = 10;
    const DEADLINE_HOURS: u64 = 72;

    // ==================== HELPER FUNCTIONS ====================

    fun start_test(): Scenario {
        ts::begin(ADMIN)
    }

    fun create_clock(scenario: &mut Scenario) {
        ts::next_tx(scenario, ADMIN);
        {
            let clock = clock::create_for_testing(ts::ctx(scenario));
            clock::share_for_testing(clock);
        };
    }

    /// Initialize TATO token and return TreasuryCapHolder
    fun init_tato(scenario: &mut Scenario) {
        ts::next_tx(scenario, ADMIN);
        {
            tani_token::init_for_testing(ts::ctx(scenario));
        };
    }

    /// Mint TATO tokens for testing
    fun mint_tato(scenario: &mut Scenario, amount: u64, recipient: address) {
        ts::next_tx(scenario, ADMIN);
        {
            let mut cap_holder = ts::take_shared<TreasuryCapHolder>(scenario);
            let coins = tani_token::mint_for_testing(&mut cap_holder, amount, ts::ctx(scenario));
            transfer::public_transfer(coins, recipient);
            ts::return_shared(cap_holder);
        };
    }

    // ==================== INITIALIZATION TESTS ====================

    #[test]
    fun test_init_marketplace_and_token() {
        let mut scenario = start_test();
        
        // Initialize marketplace
        {
            marketplace::init_for_testing(ts::ctx(&mut scenario));
        };
        
        // Initialize TATO token
        init_tato(&mut scenario);
        
        // Verify TreasuryCapHolder exists
        ts::next_tx(&mut scenario, ADMIN);
        {
            assert!(ts::has_most_recent_shared<TreasuryCapHolder>(), 0);
        };
        
        ts::end(scenario);
    }

    #[test]
    fun test_claim_faucet() {
        let mut scenario = start_test();
        init_tato(&mut scenario);
        
        // User claims faucet
        ts::next_tx(&mut scenario, BUYER);
        {
            let mut cap_holder = ts::take_shared<TreasuryCapHolder>(&scenario);
            tani_token::claim_faucet(&mut cap_holder, ts::ctx(&mut scenario));
            ts::return_shared(cap_holder);
        };
        
        // Verify user received 1000 TATO
        ts::next_tx(&mut scenario, BUYER);
        {
            let coins = ts::take_from_sender<Coin<TANI_TOKEN>>(&scenario);
            assert!(coin::value(&coins) == 1_000 * 100_000_000, 0); // 1000 TATO
            ts::return_to_sender(&scenario, coins);
        };
        
        ts::end(scenario);
    }

    // ==================== PRODUCT TESTS ====================

    #[test]
    fun test_upload_product_with_tato_price() {
        let mut scenario = start_test();
        
        ts::next_tx(&mut scenario, FARMER);
        {
            marketplace::init_for_testing(ts::ctx(&mut scenario));
        };
        
        ts::next_tx(&mut scenario, FARMER);
        {
            marketplace::upload_product(
                string::utf8(b"Organic Rice"),
                PRODUCT_PRICE, // Price in TATO
                PRODUCT_STOCK,
                ts::ctx(&mut scenario)
            );
        };
        
        ts::next_tx(&mut scenario, FARMER);
        {
            let product = ts::take_shared<Product>(&scenario);
            let (name, price, stock, farmer) = marketplace::get_product_info(&product);
            
            assert!(name == string::utf8(b"Organic Rice"), 0);
            assert!(price == PRODUCT_PRICE, 1);
            assert!(stock == PRODUCT_STOCK, 2);
            assert!(farmer == FARMER, 3);
            
            ts::return_shared(product);
        };
        
        ts::end(scenario);
    }

    // ==================== ORDER TESTS WITH TATO ====================

    #[test]
    fun test_create_order_with_tato() {
        let mut scenario = start_test();
        
        // Setup
        init_tato(&mut scenario);
        create_clock(&mut scenario);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            marketplace::init_for_testing(ts::ctx(&mut scenario));
        };
        
        ts::next_tx(&mut scenario, FARMER);
        {
            marketplace::upload_product(
                string::utf8(b"Rice"),
                PRODUCT_PRICE,
                PRODUCT_STOCK,
                ts::ctx(&mut scenario)
            );
        };
        
        // Mint TATO for buyer
        let payment_amount = PRODUCT_PRICE * ORDER_QUANTITY;
        mint_tato(&mut scenario, payment_amount, BUYER);
        
        // Buyer creates order with TATO
        ts::next_tx(&mut scenario, BUYER);
        {
            let mut product = ts::take_shared<Product>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            let payment = ts::take_from_sender<Coin<TANI_TOKEN>>(&scenario);
            
            marketplace::create_order(
                &mut product,
                ORDER_QUANTITY,
                DEADLINE_HOURS,
                payment,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            let (_, _, stock, _) = marketplace::get_product_info(&product);
            assert!(stock == PRODUCT_STOCK - ORDER_QUANTITY, 0);
            
            ts::return_shared(product);
            ts::return_shared(clock);
        };
        
        ts::next_tx(&mut scenario, BUYER);
        {
            assert!(ts::has_most_recent_for_sender<Order>(&scenario), 0);
        };
        
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = marketplace::E_INSUFFICIENT_PAYMENT)]
    fun test_create_order_insufficient_tato() {
        let mut scenario = start_test();
        
        init_tato(&mut scenario);
        create_clock(&mut scenario);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            marketplace::init_for_testing(ts::ctx(&mut scenario));
        };
        
        ts::next_tx(&mut scenario, FARMER);
        {
            marketplace::upload_product(
                string::utf8(b"Rice"),
                PRODUCT_PRICE,
                PRODUCT_STOCK,
                ts::ctx(&mut scenario)
            );
        };
        
        // Mint only 1 unit worth, but try to buy 10
        mint_tato(&mut scenario, PRODUCT_PRICE, BUYER);
        
        ts::next_tx(&mut scenario, BUYER);
        {
            let mut product = ts::take_shared<Product>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            let payment = ts::take_from_sender<Coin<TANI_TOKEN>>(&scenario);
            
            marketplace::create_order(
                &mut product,
                ORDER_QUANTITY, // Ordering 10 units
                DEADLINE_HOURS,
                payment, // But only paid for 1 unit!
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_shared(product);
            ts::return_shared(clock);
        };
        
        ts::end(scenario);
    }

    // ==================== DELIVERY CONFIRMATION WITH TATO ====================

    #[test]
    fun test_confirm_delivery_farmer_gets_tato() {
        let mut scenario = start_test();
        
        init_tato(&mut scenario);
        create_clock(&mut scenario);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            marketplace::init_for_testing(ts::ctx(&mut scenario));
        };
        
        ts::next_tx(&mut scenario, FARMER);
        {
            marketplace::upload_product(
                string::utf8(b"Rice"),
                PRODUCT_PRICE,
                PRODUCT_STOCK,
                ts::ctx(&mut scenario)
            );
        };
        
        let payment_amount = PRODUCT_PRICE * ORDER_QUANTITY;
        mint_tato(&mut scenario, payment_amount, BUYER);
        
        ts::next_tx(&mut scenario, BUYER);
        {
            let mut product = ts::take_shared<Product>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            let payment = ts::take_from_sender<Coin<TANI_TOKEN>>(&scenario);
            
            marketplace::create_order(
                &mut product,
                ORDER_QUANTITY,
                DEADLINE_HOURS,
                payment,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_shared(product);
            ts::return_shared(clock);
        };
        
        // Buyer confirms delivery
        ts::next_tx(&mut scenario, BUYER);
        {
            let order = ts::take_from_sender<Order>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            
            marketplace::confirm_delivery(order, &clock, ts::ctx(&mut scenario));
            
            ts::return_shared(clock);
        };
        
        // Verify farmer received TATO payment
        ts::next_tx(&mut scenario, FARMER);
        {
            assert!(ts::has_most_recent_for_sender<Coin<TANI_TOKEN>>(&scenario), 0);
            let payment = ts::take_from_sender<Coin<TANI_TOKEN>>(&scenario);
            assert!(coin::value(&payment) == payment_amount, 1);
            ts::return_to_sender(&scenario, payment);
        };
        
        ts::end(scenario);
    }

    // ==================== AUTOMATIC REFUND WITH TATO ====================

    #[test]
    fun test_automatic_tato_refund() {
        let mut scenario = start_test();
        
        init_tato(&mut scenario);
        create_clock(&mut scenario);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            marketplace::init_for_testing(ts::ctx(&mut scenario));
        };
        
        ts::next_tx(&mut scenario, FARMER);
        {
            marketplace::upload_product(
                string::utf8(b"Rice"),
                PRODUCT_PRICE,
                PRODUCT_STOCK,
                ts::ctx(&mut scenario)
            );
        };
        
        let payment_amount = PRODUCT_PRICE * ORDER_QUANTITY;
        mint_tato(&mut scenario, payment_amount, BUYER);
        
        ts::next_tx(&mut scenario, BUYER);
        {
            let mut product = ts::take_shared<Product>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            let payment = ts::take_from_sender<Coin<TANI_TOKEN>>(&scenario);
            
            marketplace::create_order(
                &mut product,
                ORDER_QUANTITY,
                DEADLINE_HOURS,
                payment,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_shared(product);
            ts::return_shared(clock);
        };
        
        // Advance time past deadline
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut clock = ts::take_shared<Clock>(&scenario);
            let deadline_ms = DEADLINE_HOURS * 3600 * 1000 + 1000;
            clock::increment_for_testing(&mut clock, deadline_ms);
            ts::return_shared(clock);
        };
        
        // Process expired order
        ts::next_tx(&mut scenario, RANDOM);
        {
            let order = ts::take_from_address<Order>(&scenario, BUYER);
            let clock = ts::take_shared<Clock>(&scenario);
            
            marketplace::process_expired_order(order, &clock, ts::ctx(&mut scenario));
            
            ts::return_shared(clock);
        };
        
        // Verify buyer received TATO refund
        ts::next_tx(&mut scenario, BUYER);
        {
            assert!(ts::has_most_recent_for_sender<Coin<TANI_TOKEN>>(&scenario), 0);
            let refund = ts::take_from_sender<Coin<TANI_TOKEN>>(&scenario);
            assert!(coin::value(&refund) == payment_amount, 1);
            ts::return_to_sender(&scenario, refund);
        };
        
        ts::end(scenario);
    }

    // ==================== DISPUTE WITH TATO ====================

    #[test]
    fun test_dispute_resolution_tato_split() {
        let mut scenario = start_test();
        
        init_tato(&mut scenario);
        create_clock(&mut scenario);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            marketplace::init_for_testing(ts::ctx(&mut scenario));
        };
        
        ts::next_tx(&mut scenario, FARMER);
        {
            marketplace::upload_product(
                string::utf8(b"Rice"),
                PRODUCT_PRICE,
                PRODUCT_STOCK,
                ts::ctx(&mut scenario)
            );
        };
        
        let payment_amount = PRODUCT_PRICE * ORDER_QUANTITY;
        mint_tato(&mut scenario, payment_amount, BUYER);
        
        ts::next_tx(&mut scenario, BUYER);
        {
            let mut product = ts::take_shared<Product>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            let payment = ts::take_from_sender<Coin<TANI_TOKEN>>(&scenario);
            
            marketplace::create_order(
                &mut product,
                ORDER_QUANTITY,
                DEADLINE_HOURS,
                payment,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_shared(product);
            ts::return_shared(clock);
        };
        
        ts::next_tx(&mut scenario, BUYER);
        {
            let order = ts::take_from_sender<Order>(&scenario);
            marketplace::create_dispute(&order, ts::ctx(&mut scenario));
            ts::return_to_sender(&scenario, order);
        };
        
        ts::next_tx(&mut scenario, FARMER);
        {
            let mut dispute = ts::take_shared<Dispute>(&scenario);
            marketplace::propose_compensation(&mut dispute, 70, 30, ts::ctx(&mut scenario));
            ts::return_shared(dispute);
        };
        
        ts::next_tx(&mut scenario, BUYER);
        {
            let dispute = ts::take_shared<Dispute>(&scenario);
            let order = ts::take_from_sender<Order>(&scenario);
            
            marketplace::accept_compensation(dispute, order, ts::ctx(&mut scenario));
        };
        
        let farmer_expected = (payment_amount * 70) / 100;
        let buyer_expected = payment_amount - farmer_expected;
        
        // Verify farmer received 70% in TATO
        ts::next_tx(&mut scenario, FARMER);
        {
            let payment = ts::take_from_sender<Coin<TANI_TOKEN>>(&scenario);
            assert!(coin::value(&payment) == farmer_expected, 0);
            ts::return_to_sender(&scenario, payment);
        };
        
        // Verify buyer received 30% in TATO
        ts::next_tx(&mut scenario, BUYER);
        {
            let refund = ts::take_from_sender<Coin<TANI_TOKEN>>(&scenario);
            assert!(coin::value(&refund) == buyer_expected, 1);
            ts::return_to_sender(&scenario, refund);
        };
        
        ts::end(scenario);
    }

    // ==================== FAUCET INTEGRATION TEST ====================

    #[test]
    fun test_full_flow_with_faucet() {
        let mut scenario = start_test();
        
        init_tato(&mut scenario);
        create_clock(&mut scenario);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            marketplace::init_for_testing(ts::ctx(&mut scenario));
        };
        
        // Farmer uploads product
        ts::next_tx(&mut scenario, FARMER);
        {
            marketplace::upload_product(
                string::utf8(b"Premium Rice"),
                100_000_000, // 1 TATO per unit
                100,
                ts::ctx(&mut scenario)
            );
        };
        
        // Buyer claims TATO from faucet
        ts::next_tx(&mut scenario, BUYER);
        {
            let mut cap_holder = ts::take_shared<TreasuryCapHolder>(&scenario);
            tani_token::claim_faucet(&mut cap_holder, ts::ctx(&mut scenario));
            ts::return_shared(cap_holder);
        };
        
        // Buyer buys 5 units (5 TATO total)
        ts::next_tx(&mut scenario, BUYER);
        {
            let mut product = ts::take_shared<Product>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            let mut all_tato = ts::take_from_sender<Coin<TANI_TOKEN>>(&scenario);
            
            // Split exactly 5 TATO for payment
            let payment = coin::split(&mut all_tato, 500_000_000, ts::ctx(&mut scenario));
            
            marketplace::create_order(
                &mut product,
                5,
                24,
                payment,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_shared(product);
            ts::return_shared(clock);
            ts::return_to_sender(&scenario, all_tato); // Return remaining TATO
        };
        
        // Buyer confirms delivery
        ts::next_tx(&mut scenario, BUYER);
        {
            let order = ts::take_from_sender<Order>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            
            marketplace::confirm_delivery(order, &clock, ts::ctx(&mut scenario));
            
            ts::return_shared(clock);
        };
        
        // Verify farmer got paid 5 TATO
        ts::next_tx(&mut scenario, FARMER);
        {
            let payment = ts::take_from_sender<Coin<TANI_TOKEN>>(&scenario);
            assert!(coin::value(&payment) == 500_000_000, 0); // 5 TATO
            ts::return_to_sender(&scenario, payment);
        };
        
        ts::end(scenario);
    }
}
