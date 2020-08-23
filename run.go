package main

import (
	"time"

	"github.com/0xAlchemist/go-flow-tooling/tooling"
)

const nonFungibleToken = "NonFungibleToken"
const demoToken = "DemoToken"
const rocks = "Rocks"
const auction = "Auction"

const amountNFTs = 10

// wait pauses the script for 10 seconds
// - for reading the log output
//
func wait() {
	time.Sleep(time.Second * 10)
}

func main() {
	flow := tooling.NewFlowConfigLocalhost()

	flow.DeployContract(nonFungibleToken)
	flow.DeployContract(demoToken)
	flow.DeployContract(rocks)
	flow.DeployContract(auction)

	// Setup DemoToken account with an NFT Collection and an Auction Collection
	flow.SendTransaction("setup/create_nft_collection", demoToken)
	flow.SendTransaction("setup/create_auction_collection", demoToken)

	// Setup Rocks account with DemoToken Vault
	flow.SendTransaction("setup/create_demotoken_vault", rocks)

	// Setup Auction Account with empty DemoToken Vault and Rock Collection
	flow.SendTransaction("setup/create_demotoken_vault", auction)
	flow.SendTransaction("setup/create_nft_collection", auction)

	// Setup NonFungibleToken Account with empty DemoToken Vault and Rock Collection
	flow.SendTransaction("setup/create_demotoken_vault", nonFungibleToken)
	flow.SendTransaction("setup/create_nft_collection", nonFungibleToken)

	// Mint DemoTokens for each account
	for i := 0; i < amountNFTs; i++ {
		flow.SendTransaction("setup/mint_nft", rocks)
	}

	flow.SendTransaction("setup/mint_demotokens", demoToken)

	flow.SendTransaction("list/create_auction", demoToken)

	flow.RunScript("check_auctions")

	for i := 0; i < 119; i++ {
		flow.SendTransaction("bid/place_bid", rocks)
		flow.SendTransaction("bid/place_bid", nonFungibleToken)
		flow.SendTransaction("bid/place_bid", rocks)
		flow.SendTransaction("bid/place_bid", demoToken)
		flow.SendTransaction("bid/place_bid", rocks)
		flow.SendTransaction("bid/place_bid", demoToken)
		flow.SendTransaction("bid/place_bid", auction)
		flow.SendTransaction("bid/place_bid", rocks)

		// time.Sleep(time.Second)
	}

	flow.RunScript("check_auctions")
	// Check the balances are properly setup for the auction demo
	flow.RunScript("check_bidders")

	flow.RunScript("check_epoch")

	flow.RunScript("check_orbs")
}
