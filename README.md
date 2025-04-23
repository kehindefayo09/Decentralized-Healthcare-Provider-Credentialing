# Decentralized Healthcare Provider Credentialing System

A blockchain-based system for managing healthcare provider credentials, qualifications, licenses, and facility privileges using Clarity smart contracts.

## Overview

The Decentralized Healthcare Provider Credentialing System provides a transparent, secure, and efficient way to manage healthcare practitioner credentials. By leveraging blockchain technology, it eliminates the need for repetitive verification processes across different healthcare organizations and ensures the integrity of provider information.

## Contracts

### Provider Identity Contract

Manages healthcare practitioner identities with the following features:
- Provider registration and profile management
- Secure identity verification
- Profile updates and history tracking

### Qualification Verification Contract

Validates and stores medical degrees and training information:
- Addition of qualifications by providers
- Verification by authorized entities
- Comprehensive qualification history

### License Status Contract

Tracks the active/suspended status of healthcare professionals:
- License registration by authorities
- Real-time status updates
- Expiration tracking and renewal management

### Facility Privileging Contract

Manages which procedures providers are authorized to perform at specific facilities:
- Privilege granting by facility administrators
- Status tracking (active, suspended, revoked)
- Expiration management

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Clarity development environment
- [Node.js](https://nodejs.org/) - For running tests

### Installation

1. Clone the repository:
   \`\`\`bash
   git clone https://github.com/yourusername/healthcare-credentialing.git
   cd healthcare-credentialing
   \`\`\`

2. Install dependencies:
   \`\`\`bash
   npm install
   \`\`\`

3. Deploy contracts using Clarinet:
   \`\`\`bash
   clarinet console
   \`\`\`

### Usage

#### Provider Registration

```clarity
(contract-call? .provider-identity register-provider "Dr. John Doe" "Cardiology" "john.doe@hospital.com")
