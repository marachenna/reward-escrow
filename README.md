# 🎯 Reward Escrow Contract System

A decentralized bounty hunting platform built on the Stacks blockchain using Clarity smart contracts. Post bounties, accept hunts, complete objectives, and earn rewards in a trustless environment with built-in escrow and dispute resolution.

## ✨ Features

- **Bounty Board**: Post and discover bounties with detailed objectives
- **Escrow System**: Automated reward locking and distribution
- **Milestone Tracking**: Break down hunts into 5 completable objectives
- **Dispute Resolution**: Guild master arbitration for contested bounties
- **Multi-party Authorization**: Secure access control for all participants

## 🏗️ Contract Architecture

### Core Components

- **Bounty Board**: Central registry of all posted bounties
- **Reward Vault**: Escrow system for locked STX rewards  
- **Dispute System**: Mediation framework for conflict resolution
- **Guild Master**: Administrative role for dispute arbitration

### Status Flow

```
POSTED → ACCEPTED → COMPLETED → CLAIMED
   ↓         ↓          ↓
CANCELLED  DISPUTED → RESOLVED
```

## 🎮 How It Works

### 1. Posting a Bounty
```clarity
(post-bounty bounty-id hunter-address total-reward hunt-duration objectives)
```
- Create a new bounty with specific hunter and objectives
- Define 5 completion milestones with individual rewards
- Set hunt duration and dispute deadlines

### 2. Funding the Hunt
```clarity
(fund-bounty bounty-id reward-amount)
```
- Poster deposits STX into escrow
- Bounty becomes active when fully funded
- Funds locked until completion or dispute resolution

### 3. Completing Objectives
```clarity
(complete-objective bounty-id objective-index)
```
- Hunter marks objectives as complete
- All 5 objectives must be completed
- Automatic status update to COMPLETED

### 4. Claiming Rewards
```clarity
(claim-bounty-rewards bounty-id)
```
- Poster releases funds to hunter
- Escrow automatically transfers STX
- Bounty marked as successfully completed

### 5. Dispute Resolution
```clarity
(file-bounty-dispute bounty-id dispute-details)
(issue-guild-ruling bounty-id ruling-details refund-percentage)
```
- Any participant can file disputes within deadline
- Guild master arbitrates and splits funds
- Percentage-based resolution (0-100% refund to poster)

## 🔧 Key Functions

### Read-Only Functions
- `get-bounty-info(bounty-id)` - Retrieve bounty details
- `get-locked-rewards(bounty-id)` - Check escrow balance
- `get-dispute-info(bounty-id)` - View dispute status

### Public Functions
- `post-bounty()` - Create new bounty
- `fund-bounty()` - Add funds to escrow
- `complete-objective()` - Mark objective complete
- `claim-bounty-rewards()` - Release rewards to hunter
- `file-bounty-dispute()` - Initiate dispute
- `issue-guild-ruling()` - Resolve dispute (admin only)
- `cancel-bounty()` - Cancel unfunded bounty

## 🛡️ Security Features

- **Access Control**: Role-based permissions for all operations
- **Input Validation**: Comprehensive parameter checking
- **Escrow Protection**: Funds locked until completion or resolution
- **Deadline Enforcement**: Time-bound dispute filing
- **Objective Validation**: Sum of milestone rewards must equal total

## 🚀 Getting Started

1. Deploy the contract to Stacks blockchain
2. Guild master role assigned to contract deployer
3. Posters create bounties with specific hunters
4. Fund bounties to activate hunting
5. Hunters complete objectives and claim rewards

## 📊 Data Structures

### Bounty Data
- Hunter and poster addresses
- Total reward amount and status
- Start block and deadlines
- 5 completion objectives with individual rewards

### Escrow System
- Locked reward amounts per bounty
- Automatic STX transfers on completion
- Dispute-based fund splitting

### Dispute Tracking
- Detailed dispute reasons
- Filer identification
- Guild master rulings and resolutions

## 🎯 Example Usage

```clarity
;; Post a 1000 STX bounty for data recovery
(post-bounty u1 'SP2...HUNTER 1000000000 u1008 
  (list 
    {objective-description: "Locate target database", objective-reward: 200000000, objective-completed: false}
    {objective-description: "Extract user data", objective-reward: 300000000, objective-completed: false}
    {objective-description: "Verify data integrity", objective-reward: 200000000, objective-completed: false}
    {objective-description: "Deliver encrypted backup", objective-reward: 200000000, objective-completed: false}
    {objective-description: "Provide access documentation", objective-reward: 100000000, objective-completed: false}
  ))

;; Fund the bounty
(fund-bounty u1 1000000000)

;; Hunter completes first objective  
(complete-objective u1 u0)
```

## 🤝 Contributing

Built with Clarity smart contract language for the Stacks blockchain. Contributions welcome for additional features, security improvements, and documentation.

