/// TaniTrust Marketplace - Now using TATO token!
module tanitrust::marketplace {
    use sui::object;
    use sui::tx_context;
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use tanitrust::tani_token::TANI_TOKEN; // Using TATO instead of SUI!
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::event;
    use std::string::String;

    // ==================== ERROR CODES ====================
    const E_INSUFFICIENT_STOCK: u64 = 1;
    const E_NOT_FARMER: u64 = 2;
    const E_NOT_BUYER: u64 = 3;
    const E_INVALID_ORDER: u64 = 4;
    const E_DEADLINE_NOT_PASSED: u64 = 5;
    const E_DEADLINE_PASSED: u64 = 6;
    const E_NOT_AUTHORIZED: u64 = 7;
    const E_INVALID_PERCENTAGE: u64 = 8;
    const E_DISPUTE_ALREADY_RESOLVED: u64 = 9;
    const E_INSUFFICIENT_PAYMENT: u64 = 10;

    // ==================== ORDER STATUS ====================
    const ORDER_STATUS_ESCROWED: u8 = 1;

    // ==================== DISPUTE STATUS ====================
    const DISPUTE_STATUS_PENDING: u8 = 0;

    // ==================== STRUCTS ====================

    /// Product listed by farmer (Shared Object)
    public struct Product has key, store {
        id: UID,
        name: String,
        price_per_unit: u64, // Price in TATO (smallest units)
        stock: u64,
        farmer: address,
    }

    /// Order with escrow (Owned Object)
    public struct Order has key, store {
        id: UID,
        product_id: ID,
        buyer: address,
        farmer: address,
        quantity: u64,
        total_price: u64, // Total price in TATO
        deadline: u64,
        status: u8,
        escrowed_funds: Balance<TANI_TOKEN>, // Escrowed TATO tokens
    }

    /// Dispute (Shared Object)
    public struct Dispute has key, store {
        id: UID,
        order_id: ID,
        buyer: address,
        farmer: address,
        total_amount: u64,
        farmer_percentage: u64,
        buyer_percentage: u64,
        status: u8,
        votes_for: u64,
        votes_against: u64,
    }

    /// Marketplace capability (given to admin)
    public struct MarketplaceCap has key, store {
        id: UID,
    }

    // ==================== EVENTS ====================

    public struct ProductListedEvent has copy, drop {
        product_id: ID,
        farmer: address,
        name: String,
        price: u64,
        stock: u64,
    }

    public struct OrderCreatedEvent has copy, drop {
        order_id: ID,
        product_id: ID,
        buyer: address,
        farmer: address,
        quantity: u64,
        total_price: u64,
        deadline: u64,
    }

    public struct OrderCompletedEvent has copy, drop {
        order_id: ID,
        buyer: address,
        farmer: address,
        amount: u64,
    }

    public struct RefundEvent has copy, drop {
        order_id: ID,
        buyer: address,
        amount: u64,
    }

    public struct DisputeCreatedEvent has copy, drop {
        dispute_id: ID,
        order_id: ID,
        buyer: address,
        farmer: address,
    }

    public struct DisputeResolvedEvent has copy, drop {
        dispute_id: ID,
        order_id: ID,
        farmer_amount: u64,
        buyer_amount: u64,
    }

    // ==================== INITIALIZATION ====================

    fun init(ctx: &mut TxContext) {
        let cap = MarketplaceCap {
            id: object::new(ctx),
        };
        transfer::transfer(cap, tx_context::sender(ctx));
    }

    // ==================== FARMER FUNCTIONS ====================

    /// Upload product with price (in TATO) and stock
    entry fun upload_product(
        name: String,
        price_per_unit: u64, // Price in TATO smallest units
        stock: u64,
        ctx: &mut TxContext
    ) {
        let farmer = tx_context::sender(ctx);
        let product_uid = object::new(ctx);
        let product_id = object::uid_to_inner(&product_uid);

        let product = Product {
            id: product_uid,
            name,
            price_per_unit,
            stock,
            farmer,
        };

        event::emit(ProductListedEvent {
            product_id,
            farmer,
            name,
            price: price_per_unit,
            stock,
        });

        transfer::share_object(product);
    }

    /// Update product stock
    entry fun update_stock(
        product: &mut Product,
        new_stock: u64,
        ctx: &TxContext
    ) {
        assert!(product.farmer == tx_context::sender(ctx), E_NOT_FARMER);
        product.stock = new_stock;
    }

    // ==================== BUYER FUNCTIONS ====================

    /// Create order with TATO payment
    entry fun create_order(
        product: &mut Product,
        quantity: u64,
        deadline_hours: u64,
        payment: Coin<TANI_TOKEN>, // Payment in TATO!
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let buyer = tx_context::sender(ctx);
        assert!(product.stock >= quantity, E_INSUFFICIENT_STOCK);
        
        let total_price = product.price_per_unit * quantity;
        let payment_value = coin::value(&payment);
        assert!(payment_value >= total_price, E_INSUFFICIENT_PAYMENT);

        let payment_balance = coin::into_balance(payment);
        product.stock = product.stock - quantity;
        
        let current_time = clock::timestamp_ms(clock);
        let deadline = current_time + (deadline_hours * 3600 * 1000);
        
        let order_uid = object::new(ctx);
        let order_id = object::uid_to_inner(&order_uid);
        let product_id = object::uid_to_inner(&product.id);

        let order = Order {
            id: order_uid,
            product_id,
            buyer,
            farmer: product.farmer,
            quantity,
            total_price,
            deadline,
            status: ORDER_STATUS_ESCROWED,
            escrowed_funds: payment_balance,
        };

        event::emit(OrderCreatedEvent {
            order_id,
            product_id,
            buyer,
            farmer: product.farmer,
            quantity,
            total_price,
            deadline,
        });

        transfer::transfer(order, buyer);
    }

    // ==================== DELIVERY CONFIRMATION ====================

    /// Buyer confirms delivery - releases TATO to farmer
    entry fun confirm_delivery(
        order: Order,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let buyer = tx_context::sender(ctx);
        assert!(order.buyer == buyer, E_NOT_BUYER);
        assert!(order.status == ORDER_STATUS_ESCROWED, E_INVALID_ORDER);
        
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time <= order.deadline, E_DEADLINE_PASSED);
        
        let Order {
            id: order_id,
            product_id: _,
            buyer: _buyer,
            farmer,
            quantity: _,
            total_price: _,
            deadline: _,
            status: _,
            escrowed_funds,
        } = order;

        let amount = balance::value(&escrowed_funds);
        let payment = coin::from_balance(escrowed_funds, ctx);
        transfer::public_transfer(payment, farmer);

        event::emit(OrderCompletedEvent {
            order_id: object::uid_to_inner(&order_id),
            buyer: _buyer,
            farmer,
            amount,
        });

        object::delete(order_id);
    }

    // ==================== AUTOMATIC REFUND ====================

    /// Process expired order - automatic TATO refund to buyer
    entry fun process_expired_order(
        order: Order,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(order.status == ORDER_STATUS_ESCROWED, E_INVALID_ORDER);
        
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time > order.deadline, E_DEADLINE_NOT_PASSED);
        
        let Order {
            id: order_id,
            product_id: _,
            buyer,
            farmer: _,
            quantity: _,
            total_price: _,
            deadline: _,
            status: _,
            escrowed_funds,
        } = order;

        let amount = balance::value(&escrowed_funds);
        let refund = coin::from_balance(escrowed_funds, ctx);
        transfer::public_transfer(refund, buyer);

        event::emit(RefundEvent {
            order_id: object::uid_to_inner(&order_id),
            buyer,
            amount,
        });

        object::delete(order_id);
    }

    // ==================== DISPUTE RESOLUTION ====================

    /// Buyer creates dispute
    entry fun create_dispute(
        order: &Order,
        ctx: &mut TxContext
    ) {
        let buyer = tx_context::sender(ctx);
        assert!(order.buyer == buyer, E_NOT_BUYER);
        assert!(order.status == ORDER_STATUS_ESCROWED, E_INVALID_ORDER);

        let dispute_uid = object::new(ctx);
        let dispute_id = object::uid_to_inner(&dispute_uid);
        let order_id = object::uid_to_inner(&order.id);

        let dispute = Dispute {
            id: dispute_uid,
            order_id,
            buyer,
            farmer: order.farmer,
            total_amount: order.total_price,
            farmer_percentage: 0,
            buyer_percentage: 0,
            status: DISPUTE_STATUS_PENDING,
            votes_for: 0,
            votes_against: 0,
        };

        event::emit(DisputeCreatedEvent {
            dispute_id,
            order_id,
            buyer,
            farmer: order.farmer,
        });

        transfer::share_object(dispute);
    }

    /// Propose compensation split
    entry fun propose_compensation(
        dispute: &mut Dispute,
        farmer_percentage: u64,
        buyer_percentage: u64,
        ctx: &TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(
            dispute.buyer == sender || dispute.farmer == sender,
            E_NOT_AUTHORIZED
        );
        assert!(dispute.status == DISPUTE_STATUS_PENDING, E_DISPUTE_ALREADY_RESOLVED);
        assert!(farmer_percentage + buyer_percentage == 100, E_INVALID_PERCENTAGE);

        dispute.farmer_percentage = farmer_percentage;
        dispute.buyer_percentage = buyer_percentage;
    }

    /// Accept compensation and resolve dispute - distributes TATO
    entry fun accept_compensation(
        dispute: Dispute,
        order: Order,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(
            dispute.buyer == sender || dispute.farmer == sender,
            E_NOT_AUTHORIZED
        );
        assert!(dispute.status == DISPUTE_STATUS_PENDING, E_DISPUTE_ALREADY_RESOLVED);
        assert!(
            dispute.farmer_percentage + dispute.buyer_percentage == 100,
            E_INVALID_PERCENTAGE
        );

        let order_id = object::uid_to_inner(&order.id);
        assert!(dispute.order_id == order_id, E_INVALID_ORDER);

        let Dispute {
            id: dispute_id,
            order_id: _order_id,
            buyer,
            farmer,
            total_amount: _,
            farmer_percentage,
            buyer_percentage: _,
            status: _,
            votes_for: _,
            votes_against: _,
        } = dispute;

        let Order {
            id: order_obj_id,
            product_id: _,
            buyer: _,
            farmer: _,
            quantity: _,
            total_price: _,
            deadline: _,
            status: _,
            escrowed_funds: mut escrowed_funds,
        } = order;

        let total = balance::value(&escrowed_funds);
        let farmer_amount = (total * farmer_percentage) / 100;
        let buyer_amount = total - farmer_amount;

        let farmer_balance = balance::split(&mut escrowed_funds, farmer_amount);
        let buyer_balance = escrowed_funds;

        if (farmer_amount > 0) {
            let farmer_payment = coin::from_balance(farmer_balance, ctx);
            transfer::public_transfer(farmer_payment, farmer);
        } else {
            balance::destroy_zero(farmer_balance);
        };

        if (buyer_amount > 0) {
            let buyer_payment = coin::from_balance(buyer_balance, ctx);
            transfer::public_transfer(buyer_payment, buyer);
        } else {
            balance::destroy_zero(buyer_balance);
        };

        event::emit(DisputeResolvedEvent {
            dispute_id: object::uid_to_inner(&dispute_id),
            order_id: _order_id,
            farmer_amount,
            buyer_amount,
        });

        object::delete(dispute_id);
        object::delete(order_obj_id);
    }

    /// Vote on dispute (DAO voting)
    entry fun vote_on_dispute(
        dispute: &mut Dispute,
        vote_for: bool,
        _ctx: &TxContext
    ) {
        assert!(dispute.status == DISPUTE_STATUS_PENDING, E_DISPUTE_ALREADY_RESOLVED);

        if (vote_for) {
            dispute.votes_for = dispute.votes_for + 1;
        } else {
            dispute.votes_against = dispute.votes_against + 1;
        };
    }

    // ==================== VIEW FUNCTIONS ====================

    public fun get_product_info(product: &Product): (String, u64, u64, address) {
        (product.name, product.price_per_unit, product.stock, product.farmer)
    }

    public fun get_order_status(order: &Order): u8 {
        order.status
    }

    public fun get_order_details(order: &Order): (address, address, u64, u64, u64, u8) {
        (
            order.buyer,
            order.farmer,
            order.quantity,
            order.total_price,
            order.deadline,
            order.status
        )
    }

    public fun get_dispute_info(dispute: &Dispute): (u64, u64, u64, u8) {
        (
            dispute.farmer_percentage,
            dispute.buyer_percentage,
            dispute.votes_for,
            dispute.status
        )
    }

    // ==================== TEST ONLY ====================
    
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
