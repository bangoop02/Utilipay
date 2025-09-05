# 💧⚡ Utilipay - Smart Utility Billing Contract

A decentralized utility billing platform built on Stacks blockchain that enables transparent and automated payment of water and electricity bills using oracle-based consumption data.

## 🌟 Features

- **Multi-Utility Support**: Handle both water 💧 and electricity ⚡ billing
- **Oracle Integration**: Authorized oracles can submit consumption data
- **Prepaid System**: Customers can add balance and pay bills automatically
- **Transparent Billing**: All billing data stored on-chain
- **Rate Management**: Dynamic utility rate updates by contract owner
- **Customer Management**: Complete customer registration and tracking system

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd utilipay
clarinet check
```

## 📋 Usage Instructions

### For Customers

1. **Register as Customer** 👤
   ```clarity
   (contract-call? .Utilipay register-customer "John Doe")
   ```

2. **Add Balance** 💰
   ```clarity
   (contract-call? .Utilipay add-balance u1000)
   ```

3. **Pay Bill** 💳
   ```clarity
   (contract-call? .Utilipay pay-bill u1)
   ```

4. **Check Balance** 📊
   ```clarity
   (contract-call? .Utilipay get-customer-balance tx-sender)
   ```

### For Contract Owner

1. **Authorize Oracle** 🔐
   ```clarity
   (contract-call? .Utilipay authorize-oracle 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
   ```

2. **Update Rates** 📈
   ```clarity
   (contract-call? .Utilipay update-water-rate u60)
   (contract-call? .Utilipay update-electricity-rate u80)
   ```

### For Authorized Oracles

1. **Create Bill** 📄
   ```clarity
   (contract-call? .Utilipay create-bill 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u1 u100 u1000)
   ```

## 🔧 Contract Functions

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `register-customer` | Register new customer | `name` |
| `add-balance` | Add funds to customer account | `amount` |
| `pay-bill` | Pay utility bill | `bill-id` |
| `create-bill` | Create new utility bill (oracle only) | `customer`, `utility-type`, `consumption`, `due-date` |
| `authorize-oracle` | Authorize oracle (owner only) | `oracle` |
| `update-water-rate` | Update water billing rate (owner only) | `new-rate` |
| `update-electricity-rate` | Update electricity billing rate (owner only) | `new-rate` |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-customer` | Get customer details | Customer data |
| `get-customer-balance` | Get customer balance | Balance amount |
| `get-bill` | Get bill details | Bill data |
| `get-water-rate` | Get current water rate | Rate per unit |
| `get-electricity-rate` | Get current electricity rate | Rate per unit |
| `is-oracle-authorized` | Check if oracle is authorized | Boolean |

## 🏗️ Contract Architecture

### Constants
- **Utility Types**: Water (1), Electricity (2)
- **Error Codes**: Comprehensive error handling system
- **Default Rates**: Water (50), Electricity (75)

### Data Structures
- **Customers**: Registration and payment history
- **Bills**: Consumption-based billing records
- **Balances**: Prepaid customer balances
- **Oracles**: Authorized data providers

## 🧪 Testing

```bash
clarinet test
```

## 🔒 Security Features

- Owner-only administrative functions
- Oracle authorization system
- Balance validation before payments
- Duplicate registration prevention
- Bill payment verification

## 📊 Utility Types

- **Water** 💧: Type ID `1`
- **Electricity** ⚡: Type ID `2`

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For support and questions, please open an issue in the repository.

---

