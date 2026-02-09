# TaniTrust 🌾

**Decentralized Agricultural Marketplace on Sui**

A marketplace for farmers to sell directly to buyers using **TATO tokens**.

---

## 🚀 Quick Start for Frontend

### 1. Network & IDs
**Network**: Sui Testnet  
**Package ID**: `0xe6b6d6ace1137e5795824de0f81bc65608362861247f0d152653b0c44ccfc69b`

### 2. Copy-Paste Constants
Add this to your frontend config:

```typescript
export const CONSTANTS = {
  NETWORK: 'testnet',
  PACKAGE_ID: '0xe6b6d6ace1137e5795824de0f81bc65608362861247f0d152653b0c44ccfc69b',
  // Shared Object for Minting TATO
  TREASURY_CAP: '0x64852a7680d5dda8e00c97a9b74efb91ebfbc6f8997b95c7f3dff8fb4f88c421',
  // TATO Token Type
  COIN_TYPE: '0xe6b6d6ace1137e5795824de0f81bc65608362861247f0d152653b0c44ccfc69b::tani_token::TANI_TOKEN',
  // Marketplace Logic
  MARKETPLACE_MODULE: 'marketplace',
  TOKEN_MODULE: 'tani_token'
};
```

---

## 🛠️ Key Functions

### 1. Get Free Tokens (Faucet) 🪙
Everyone can call this to get 1,000 TATO.
- **Function**: `tani_token::claim_faucet`
- **Args**: `[TREASURY_CAP]`

### 2. For Farmers 👨‍🌾
- **Upload Product**: `marketplace::upload_product`
  - Args: `name` (string), `price` (u64), `stock` (u64)
- **Update Stock**: `marketplace::update_stock`
  - Args: `product_id`, `new_stock`

### 3. For Buyers 🛒
- **Buy Product**: `marketplace::create_order`
  - Args: `product_id`, `quantity`, `deadline_hours`, `payment_coin` (TATO), `clock`
- **Confirm Delivery**: `marketplace::confirm_delivery`
  - Args: `order_id`, `clock`

---

## ℹ️ Token Info
- **Symbol**: TATO
- **Decimals**: 8 (Display value = Raw Value / 100,000,000)
- **Example**: 500 TATO = `50000000000` units

---

## 🧪 Run Tests
```bash
sui move test
```
