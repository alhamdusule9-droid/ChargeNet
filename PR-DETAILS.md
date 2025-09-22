# EV Charging Network Smart Contracts

This pull request implements the core smart contracts for ChargeNet, a blockchain-based EV charging network with prepaid token functionality.

## Overview

ChargeNet enables electric vehicle owners to purchase charging tokens in advance and use them across a network of registered charging stations. The system consists of two main smart contracts that work together to provide a seamless charging experience.

## Smart Contracts

### 1. Charging Tokens Contract (`charging-tokens.clar`)

**Features:**
- Token purchase system using STX cryptocurrency
- User balance management and tracking
- Token transfer capabilities between users  
- Consumption tracking by authorized charging stations
- Purchase and transfer history logging
- Station authorization management

**Key Functions:**
- `purchase-tokens` - Buy charging tokens with STX
- `transfer-tokens` - Transfer tokens between users
- `consume-tokens` - Deduct tokens during charging (stations only)
- `get-balance` - Check user token balance

### 2. Charging Station Contract (`charging-station.clar`)

**Features:**
- Station registration and management system
- Charging session lifecycle management
- Dynamic pricing based on power rating and duration
- Session history and tracking
- Station earnings calculation
- Network statistics and analytics

**Key Functions:**
- `register-station` - Register new charging stations
- `start-session` - Begin charging session
- `end-session` - Complete session and consume tokens
- `get-station-info` - Retrieve station details

## System Integration

The contracts are designed to work together:
1. Users purchase tokens through the tokens contract
2. Stations register through the station contract
3. Sessions are managed by the station contract
4. Token consumption is handled via cross-contract calls

## Token Economics

- **Token Price**: 1 STX = 1 charging token
- **Minimum Purchase**: 1 token
- **Maximum Purchase**: 10,000 tokens per transaction
- **Base Rate**: 100 tokens per hour (configurable per station)
- **Fast Charging**: 2x multiplier for high-energy sessions

## Security Features

- Owner-only functions for contract administration
- Station authorization system to prevent unauthorized token consumption
- Balance validation before token transfers and consumption
- Session state management to prevent double-spending
- Emergency session cancellation capabilities

## Network Benefits

- **Interoperability**: Single token works across all network stations
- **Transparency**: All transactions and rates recorded on-chain  
- **Decentralization**: No central authority controls operations
- **Scalability**: Stations can join/leave network independently
- **Fraud Prevention**: Smart contract logic prevents manipulation

This implementation provides a solid foundation for a decentralized EV charging network that can scale to support thousands of stations and users while maintaining security and transparency.
