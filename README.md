# TaniTrust 🌾

Decentralized Agricultural Marketplace on Sui using **TATO tokens**.

---

## 🚀 Frontend Configuration

```typescript
export const TANITRUST_CONFIG = {
  NETWORK: 'testnet',
  PACKAGE_ID: '0x49baa0988a11ca9c4e40216b826fd19d86af3f427459408a6720e7c6fad2bd15',
  TREASURY_CAP_HOLDER: '0xe0857d41cb5e88091fca3fd22ba3e333746950cbe7bbbb1f7870db502d725b9f',
  TATO_COIN_TYPE: '0x49baa0988a11ca9c4e40216b826fd19d86af3f427459408a6720e7c6fad2bd15::tani_token::TANI_TOKEN',
  CLOCK_OBJECT: '0x6', // Sui system clock
};
```

---

## 💰 TATO Token

- **Symbol**: TATO
- **Decimals**: 8
- **1 TATO** = `100000000` units

---

## 📋 Smart Contract Functions

### Token Functions

#### Claim Free TATO (Faucet)
```typescript
tx.moveCall({
  target: `${PACKAGE_ID}::tani_token::claim_faucet`,
  arguments: [tx.object(TREASURY_CAP_HOLDER)],
});
// Returns: 1,000 TATO
```

### Farmer Functions

#### Upload Product
```typescript
tx.moveCall({
  target: `${PACKAGE_ID}::marketplace::upload_product`,
  arguments: [
    tx.pure('Organic Rice'),    // name
    tx.pure(50000000),          // price (0.5 TATO)
    tx.pure(1000),              // stock
    tx.pure(24),                // fulfillment_time (in hours) <-- NEW!
  ],
});
```

#### Update Stock
```typescript
tx.moveCall({
  target: `${PACKAGE_ID}::marketplace::update_stock`,
  arguments: [tx.object(productId), tx.pure(500)],
});
```

#### Delete Product
```typescript
tx.moveCall({
  target: `${PACKAGE_ID}::marketplace::delete_product`,
  arguments: [tx.object(productId)],
});
```

### Buyer Functions

#### Create Order
```typescript
const [coin] = tx.splitCoins(tx.gas, [tx.pure(500000000)]); // 5 TATO
tx.moveCall({
  target: `${PACKAGE_ID}::marketplace::create_order`,
  arguments: [
    tx.object(productId),
    tx.pure(10),                // quantity
    // deadline_hours removed - auto calculated from product.fulfillment_time
    coin,                       // payment
    tx.object('0x6'),           // clock
  ],
});
```

#### Confirm Delivery
```typescript
tx.moveCall({
  target: `${PACKAGE_ID}::marketplace::confirm_delivery`,
  arguments: [tx.object(orderId), tx.object('0x6')],
});
```

#### Process Expired Order (Refund)
```typescript
tx.moveCall({
  target: `${PACKAGE_ID}::marketplace::process_expired_order`,
  arguments: [tx.object(orderId), tx.object('0x6')],
});
```

### Dispute Functions

#### Create Dispute
```typescript
tx.moveCall({
  target: `${PACKAGE_ID}::marketplace::create_dispute`,
  arguments: [tx.object(orderId)],
});
// Note: Dispute is a SHARED object
```

#### Propose Compensation
```typescript
tx.moveCall({
  target: `${PACKAGE_ID}::marketplace::propose_compensation`,
  arguments: [
    tx.object(disputeId), // Shared object
    tx.pure(70),  // farmer_percentage
    tx.pure(30),  // buyer_percentage
  ],
});
```

#### Accept Compensation
```typescript
tx.moveCall({
  target: `${PACKAGE_ID}::marketplace::accept_compensation`,
  arguments: [tx.object(disputeId), tx.object(orderId)],
});
// Note: Requires mutable reference to shared Dispute object
```

---

## 📖 View Functions

```typescript
// Get product info
marketplace::get_product_info(product): (name, price, stock, farmer, fulfillment_time)

// Get order details
marketplace::get_order_details(order): (buyer, farmer, quantity, total_price, deadline, status)

// Get order status
marketplace::get_order_status(order): status

// Get dispute info
marketplace::get_dispute_info(dispute): (farmer_%, buyer_%, votes_for, status)
```

---

## 🧪 Testing

```bash
sui move test
```

---

## 🔗 Explorer

[View on Sui Explorer](https://suiexplorer.com/object/0x49baa0988a11ca9c4e40216b826fd19d86af3f427459408a6720e7c6fad2bd15?network=testnet)
