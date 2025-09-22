# ChargeNet - EV Charging Network Smart Contract System

ChargeNet is a blockchain-based EV charging network that utilizes prepaid charging tokens for seamless electric vehicle charging experiences. The system enables users to purchase charging tokens in advance and use them across a network of charging stations.

## Overview

ChargeNet operates on two main smart contracts:
- **Charging Tokens Contract**: Manages prepaid token purchases, balances, and transfers
- **Charging Station Contract**: Handles charging station registration, session management, and token consumption

## Features

### Charging Tokens System
- **Token Purchase**: Users can buy charging tokens using STX
- **Balance Management**: Track token balances for each user
- **Token Transfer**: Allow users to transfer tokens between accounts
- **Usage Tracking**: Monitor total tokens purchased and consumed

### Charging Station Network
- **Station Registration**: Register new charging stations on the network
- **Session Management**: Start and end charging sessions
- **Token Consumption**: Deduct tokens based on charging duration/energy
- **Station Status**: Track active/inactive stations and their availability

## System Architecture

The ChargeNet system consists of two interconnected smart contracts:

1. **charging-tokens.clar**: Core token management functionality
2. **charging-station.clar**: Charging station operations and session handling

## Key Benefits

- **Prepaid System**: Users purchase tokens in advance, enabling predictable charging costs
- **Network Interoperability**: Single token system works across all registered stations
- **Transparent Pricing**: All costs and rates are recorded on-chain
- **Decentralized Management**: No central authority controls the charging network
- **Fraud Prevention**: Smart contract logic prevents double-spending and unauthorized usage

## Use Cases

- **Fleet Management**: Companies can pre-purchase tokens for their EV fleets
- **Public Charging**: Individual users can buy tokens for personal vehicle charging
- **Station Operations**: Charging station operators can join the network and earn revenue
- **Token Trading**: Users can transfer unused tokens to other network participants

## Getting Started

1. Clone this repository
2. Install Clarinet: `npm install -g @hirosystems/clarinet`
3. Run contract checks: `clarinet check`
4. Deploy to testnet for testing
5. Integrate with your EV charging infrastructure

## Contract Deployment

The contracts are designed to be deployed on Stacks blockchain and can be easily integrated with existing EV charging station hardware and software systems.

## Contributing

This is an open-source project. Contributions are welcome to improve the charging network functionality and expand the system capabilities.

## License

MIT License - Feel free to use and modify for your EV charging network needs.
