package main

import (
	"time"

	"github.com/0xAlchemist/go-flow-tooling/tooling"
)

// Smart Contract Accounts
const nonFungibleToken = "NonFungibleToken"
const demoToken = "DemoToken"
const rocks = "Rocks"
const auction = "Auction"

// Auction Host Account
const auctionHost = "AuctionHost"

// Bidder Accounts
const bidder1 = "Bidder1"
const bidder2 = "Bidder2"
const bidder3 = "Bidder3"
const bidder4 = "Bidder4"
const bidder5 = "Bidder5"
const bidder6 = "Bidder6"

// The amount of NFTs to mint
const amountNFTs = 10

// wait pauses the script for 10 seconds
// - for reading the log output
//
func wait() {
	time.Sleep(time.Second * 4)
}

func main() {
	// Initialize our tooling
	flow := tooling.NewFlowConfigLocalhost()

	// Deploy Smart Contracts to Emulator Accounts
	flow.DeployContract(nonFungibleToken)
	flow.DeployContract(demoToken)
	flow.DeployContract(rocks)
	flow.DeployContract(auction)

	println("Smart Contracts Deployed...")
	wait()

	// Setup DemoToken account with an NFT Collection and an Auction Collection
	flow.SendTransaction("setup/create_nft_collection", demoToken)
	flow.SendTransaction("setup/create_auction_collection", demoToken)

	println("First account has been set up")
	wait()

	// Setup Rocks account with DemoToken Vault
	flow.SendTransaction("setup/create_demotoken_vault", rocks)

	println("Second account has been set up")
	wait()

	// Setup Auction Account with empty DemoToken Vault and Rock Collection
	flow.SendTransaction("setup/create_demotoken_vault", auction)
	flow.SendTransaction("setup/create_nft_collection", auction)

	println("Third account has been set up")
	wait()

	// Setup NonFungibleToken Account with empty DemoToken Vault and Rock Collection
	flow.SendTransaction("setup/create_demotoken_vault", nonFungibleToken)
	flow.SendTransaction("setup/create_nft_collection", nonFungibleToken)

	println("Fourth account has been set up")
	wait()

	// Mint DemoTokens for each account
	for i := 0; i < amountNFTs; i++ {
		flow.SendTransaction("setup/mint_nft", rocks)
	}

	println("NFTs have been minted")
	wait()

	flow.SendTransaction("setup/mint_demotokens", demoToken)

	println("Fungible tokens have been minted and deposited")
	wait()

	flow.SendTransaction("list/create_auction", demoToken)

	println("A new auction has been created")
	wait()

	flow.RunScript("check_auctions")

	println("Peep my auction... 0.o")
	println("Now we're placing bids!")
	wait()

	for i := 0; i < 5; i++ {
		flow.SendTransaction("bid/place_bid", rocks)
		flow.SendTransaction("bid/place_bid", nonFungibleToken)
		flow.SendTransaction("bid/place_bid", rocks)
		flow.SendTransaction("bid/place_bid", demoToken)
		flow.SendTransaction("bid/place_bid", rocks)
		flow.SendTransaction("bid/place_bid", demoToken)
		flow.SendTransaction("bid/place_bid", auction)
		flow.SendTransaction("bid/place_bid", rocks)
	}

	flow.RunScript("check_account")

	println("Here's the first account contents. Pretty shnazzy...")
	println("Now we're going to fast forward the auction to the end")
	wait()

	for i := 0; i < 15; i++ {
		flow.SendTransaction("run/check_update_epoch", demoToken)
	}

	println("The auction is over! Time to payout the orb rewards to the owners")
	wait()

	flow.SendTransaction("payout/payout_orbs", demoToken)

	flow.RunScript("check_account")

	println("WE BALLIN!!")
	wait()

	flow.RunScript("check_bidders")

	println("All remaining bidders have their tokens back")
	wait()

	flow.RunScript("check_orbs")

	println("All orbs are empty. Balances and prizes have been paid to the owners")
}
