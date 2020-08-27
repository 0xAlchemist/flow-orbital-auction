package main

import (
	"fmt"

	"github.com/onflow/cadence"
	"github.com/versus-flow/go-flow-tooling/tooling"
)

// Smart Contract Accounts
const nonFungibleToken = "NonFungibleToken"
const demoToken = "DemoToken"
const rocks = "Rocks"
const auction = "Auction"

// Bidder Accounts
const amountBidders = 6

// The amount of NFTs to mint
const amountNFTs = 10

func ufix(input string) cadence.UFix64 {
	amount, err := cadence.NewUFix64(input)
	if err != nil {
		panic(err)
	}
	return amount
}

// Start from root dir with makefile
func main() {
	// Initialize our tooling
	flow := tooling.NewFlowConfigLocalhost()

	println("Orbital Auction | Proof of Concept Demo")
	// fmt.Scanln()

	// Deploy Smart Contracts to Emulator Accounts
	flow.DeployContract(nonFungibleToken)
	flow.DeployContract(demoToken)
	flow.DeployContract(rocks)
	flow.DeployContract(auction)

	println("Smart Contracts Deployed...")

	println("Set up the auction host account:")
	println("- create empty FungibleToken Vault")
	println("- create empty NonFungibleToken Collection")
	println("- create empty OrbitalAuction Collection")

	// fmt.Scanln()

	// Setup DemoToken account with an NFT Collection and an Auction Collection
	flow.SendTransaction("setup/create_demotoken_vault", auction)
	flow.SendTransaction("setup/create_nft_collection", auction)
	flow.SendTransaction("setup/create_auction_collection", auction)

	println("Create and set up the 6 bidder accounts:")
	println("- create empty FungibleToken Vault")
	println("- create empty NonFungibleToken Collection")

	// fmt.Scanln()

	var bidders = make([]string, 0)
	for i := 1; i <= amountBidders; i++ {
		accountName := fmt.Sprintf("Bidder%d", i)

		flow.CreateAccount(accountName)
		bidders = append(bidders, accountName)
	}

	for _, bidder := range bidders {
		// Setup Auction Account with empty DemoToken Vault and Rock Collection
		flow.SendTransaction("setup/create_demotoken_vault", bidder)
		flow.SendTransaction("setup/create_nft_collection", bidder)
	}

	println(fmt.Sprintf("Mint %d NFTs to use as auction prizes", amountNFTs))

	// fmt.Scanln()

	// Mint DemoTokens for each account
	for i := 0; i < amountNFTs; i++ {
		flow.SendTransactionWithArguments("setup/mint_nft", rocks, flow.FindAddress(auction))
	}

	println("NFTs have been minted and deposited in the auction owners NFT collection")

	println("Create a new FungibleToken minter with allowed amount of 1,000,000 tokens")
	// fmt.Scanln()

	flow.SendTransactionWithArguments("setup/new_demotoken_minter", demoToken, ufix("1000000.0"))

	println("Mint tokens for auction owner")
	// fmt.Scanln()

	flow.SendTransactionWithArguments("setup/mint_demotokens", demoToken,
		flow.FindAddress(auction), // Receiver address
		ufix("100000.0"))          // Amount of minted tokens

	println("Mint tokens for the bidders")
	// fmt.Scanln()

	for _, bidder := range bidders {
		flow.SendTransactionWithArguments("setup/mint_demotokens", demoToken,
			flow.FindAddress(bidder), // Receiver address
			ufix("100000.0"))         // Amount of minted tokens

		println("Fungible tokens have been minted and deposited for", bidder)
	}

	// CREATE NEW ORBITAL AUCTION

	println("Create a new Orbital Auction")
	println("Epochs - 8")
	println("Epoch Length - 12 blocks")

	flow.SendTransactionWithArguments("list/create_auction", auction,
		cadence.UInt64(8),  // Epoch Count
		cadence.UInt64(12)) // Epoch Length in Blocks

	println("A new auction has been created")

	flow.RunScript("check_auctions", flow.FindAddress(auction))

	// BID ON THE AUCTION
	for i := 0; i < 15; i++ {
		flow.SendTransactionWithArguments("bid/place_bid", bidders[0],
			flow.FindAddress(auction),
			cadence.UInt64(1),
			ufix("60.0"))

		flow.SendTransactionWithArguments("bid/place_bid", bidders[1],
			flow.FindAddress(auction),
			cadence.UInt64(1),
			ufix("65.0"))

		flow.SendTransactionWithArguments("bid/place_bid", bidders[2],
			flow.FindAddress(auction),
			cadence.UInt64(1),
			ufix("55.0"))

		flow.SendTransactionWithArguments("bid/place_bid", bidders[3],
			flow.FindAddress(auction),
			cadence.UInt64(1),
			ufix("25.0"))

		flow.SendTransactionWithArguments("bid/place_bid", bidders[4],
			flow.FindAddress(auction),
			cadence.UInt64(1),
			ufix("35.0"))

		flow.SendTransactionWithArguments("bid/place_bid", bidders[5],
			flow.FindAddress(auction),
			cadence.UInt64(1),
			ufix("62.0"))
	}

	// CHECK CURRENT EPOCH
	flow.RunScript("check_epoch", flow.FindAddress(auction), cadence.UInt64(1))

	// CHECK ACTIVE BIDDERS
	flow.RunScript("check_bidders", flow.FindAddress(auction), cadence.UInt64(1))

	// CHECK BIDDER ACCOUNTS
	for _, bidder := range bidders {
		flow.RunScript("check_account", flow.FindAddress(bidder))
	}

	// CHECK ORBS
	flow.RunScript("check_orbs", flow.FindAddress(auction), cadence.UInt64(1))

	println("press ENTER to complete the auction")
	fmt.Scanln()

	// COMPLETE THE AUCTION

	for i := 0; i < 15; i++ {
		flow.SendTransactionWithArguments("run/check_update_epoch", auction, cadence.UInt64(1))
	}

	flow.SendTransactionWithArguments("payout/payout_orbs", auction, cadence.UInt64(1))

	// CHECK CURRENT EPOCH
	flow.RunScript("check_epoch", flow.FindAddress(auction), cadence.UInt64(1))

	// CHECK ACTIVE BIDDERS
	flow.RunScript("check_bidders", flow.FindAddress(auction), cadence.UInt64(1))

	// CHECK BIDDER ACCOUNTS
	for _, bidder := range bidders {
		flow.RunScript("check_account", flow.FindAddress(bidder))
	}

	// CHECK ORBS
	flow.RunScript("check_orbs", flow.FindAddress(auction), cadence.UInt64(1))

}
