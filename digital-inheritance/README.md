# Digital Will Smart Contract

A secure and robust smart contract for managing digital assets inheritance on the Stacks blockchain. This contract enables users to create, manage, and execute digital wills for their blockchain assets, including STX, Fungible Tokens, and NFTs.

## Overview

The Digital Will smart contract provides a decentralized solution for digital asset inheritance. It implements a comprehensive system for creating and executing wills, with features such as:
- Multiple beneficiary support
- Multiple asset type handling
- Backup executor system
- Activity monitoring
- Event logging
- Automated execution conditions

## Features

### Core Functionality
- **Will Creation**: Create digital wills with multiple beneficiaries and asset types
- **Asset Management**: Support for STX, Fungible Tokens, and NFTs
- **Backup Executors**: Designate multiple trusted executors
- **Activity Monitoring**: Track testator activity with customizable thresholds
- **Event Logging**: On-chain recording of all significant actions
- **Automated Execution**: Trigger-based execution after inactivity period

### Security Features
- Comprehensive authorization checks
- Multi-level validation
- Activity-based execution protection
- Revocation capability
- Error handling and recovery

## Functions

### Public Functions

#### Will Management
1. `create-digital-will`
   - Creates a new digital will
   - Parameters:
     - beneficiary-list
     - backup-executors
     - inactivity-threshold
     - stx-assets
     - ft-assets
     - nft-assets

2. `update-inactivity-threshold`
   - Updates the inactivity period threshold
   - Parameter: new-threshold (uint)

3. `update-backup-executors`
   - Updates the list of backup executors
   - Parameter: new-executors (list of principals)

4. `record-activity`
   - Records testator activity to prevent automatic execution
   - No parameters required

5. `execute-digital-will`
   - Executes the will and distributes assets
   - Parameter: testator (principal)

6. `revoke-digital-will`
   - Deactivates an active will
   - No parameters required

### Read-Only Functions

1. `get-digital-will`
   - Retrieves will information
   - Parameter: testator (principal)

2. `get-event`
   - Retrieves event information
   - Parameter: event-id (uint)

3. `check-will-status`
   - Checks will status and execution eligibility
   - Parameter: testator (principal)

## Events

The contract logs the following events:
- WILL_CREATED
- THRESHOLD_UPDATED
- EXECUTORS_UPDATED
- ACTIVITY_RECORDED
- WILL_EXECUTED
- WILL_REVOKED

## Security Measures

### Authorization Checks
- Testator-only actions
- Executor validation
- Activity threshold verification
- Execution conditions validation

### Asset Protection
- Multi-step execution process
- Asset transfer validation
- Failed transfer handling
- Revocation capability

## Asset Management

### Supported Asset Types
1. STX (native token)
   - Direct transfers using stx-transfer?

2. Fungible Tokens
   - Transfers via FT trait
   - Contract validation

3. NFTs
   - Transfers via NFT trait
   - Token ownership verification

## Error Handling

### Error Codes
```clarity
ERR-UNAUTHORIZED (u100)
ERR-WILL-EXISTS (u101)
ERR-WILL-NOT-FOUND (u102)
ERR-INVALID-BENEFICIARY-DATA (u103)
ERR-WILL-ALREADY-EXECUTED (u104)
ERR-WILL-INACTIVE (u105)
ERR-INVALID-EXECUTOR (u106)
ERR-INVALID-PERIOD (u107)
ERR-TRANSFER-FAILED (u108)
```

## Best Practices

### For Testators
1. Regularly record activity to prevent premature execution
2. Maintain accurate beneficiary information
3. Keep asset lists updated
4. Choose reliable backup executors
5. Set appropriate inactivity thresholds

### For Executors
1. Verify execution conditions before attempting
2. Monitor testator activity
3. Ensure asset availability before execution
4. Document execution attempts
5. Coordinate with other backup executors

### For Beneficiaries
1. Keep principal addresses up to date
2. Monitor will status
3. Coordinate with executors
4. Verify received assets after execution

### Mainnet Deployment
1. Review all contract parameters
2. Verify trait implementations
3. Test with minimal assets first
4. Monitor initial transactions
5. Gradually increase usage

## Contributing

Contributions are welcome! Please follow these steps:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request