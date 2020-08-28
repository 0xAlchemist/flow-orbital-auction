# Orbital Auction Smart Contract

A composable auction contract with a custom fungible and non-fungible token for testing. Both tokens conform to the token standards found in the Flow repo: [FT](https://github.com/onflow/flow-ft/blob/master/contracts/FungibleToken.cdc) | [NFT](https://github.com/onflow/flow-nft/blob/master/contracts/NonFungibleToken.cdc)

## Technical Demonstration Video

[![YouTube Video](https://img.youtube.com/vi/WwAQOymEvkA/0.jpg)](https://www.youtube.com/watch?v=WwAQOymEvkA)

## Deployment

This demo is currently available for download and deployment with the Flow CLI and VS Code Extension

### Go Tooling Deployment (Recommended)

1. Ensure Go is [installed on your machine](https://golang.org/dl/) `recommended version 1.14^`
2. [Install the Flow CLI](https://docs.onflow.org/docs/cli) and VS Code Extension
3. Run `git clone https://github.com/0xAlchemist/orbital-auction` in a terminal window
4. Change to the project directory `cd orbital-auction`
5. Run `mv flow.sample.json flow.json` to rename `flow.sample.json` to `flow.json` 
6. Run `flow emulator start -v` in terminal window 1
7. Run `make` in terminal window 2

## Technical Limitations

- Does not handle a case where there are two competing "highest bids"
- Does not handle a case where there are no bids for an Epoch
- There is no commission percentage for auction host or token sellers
- There is no method to safely return Rocks (NFTs) to the auction host's collection
