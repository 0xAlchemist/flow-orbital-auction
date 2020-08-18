// Auction.cdc
//
// The Orbital Auction contract is a mathematical Auction game on the Flow blockchain.
//
// This contract allows users to put their NFTs up for sale. Other users
// can purchase these NFTs with fungible tokens.
//
import FungibleToken from 0xee82856bf20e2aa6
import NonFungibleToken from 0x01cf0e2f2f715450

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - NonFungibleToken.cdc
// Acct 2 - 0x179b6b1cb6755e31 - DemoToken.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - Rocks.cdc
// Acct 4 - 0xe03daebed8ca0615 - Auction.cdc
//

pub contract OrbitalAuction {

    // Events
    pub event NewCollectionCreated(block: UInt64)
    pub event NewAuctionCreated(id: UInt64, totalSessions: UInt64)
    pub event NewBid(auctionID: UInt64, address: Address, bidTotal: UFix64)
    pub event updatedBid(auctionID: UInt64, address: Address, bidTotal: UFix64)
    // pub event AuctionSettled(tokenID: UInt64, price: UFix64)

    // AuctionPublic is a resource interface that restricts users to...
    //
    pub resource interface AuctionCollectionPublic {
        pub fun placeBid(
            auctionID: UInt64,
            vaultCap: Capability<&{FungibleToken.Receiver}>,
            collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>,
            bidTokens: @FungibleToken.Vault,
            address: Address
        )
        pub fun getAuctionInfo(): [&Auction]
        pub fun getAuctionBidders(_ id: UInt64): {Address: UFix64}
    }

    // Auction contains the Resources and metadata for a single auction
    pub resource Auction {

        access(contract) var bidders: @{Address: Bidder}
        access(contract) var prizes: @[NonFungibleToken.NFT]
        access(contract) let vault: @FungibleToken.Vault
        access(contract) var meta: Meta

        init(prizes: @[NonFungibleToken.NFT], meta: Meta, vault: @FungibleToken.Vault) {
            self.bidders <- {}
            self.prizes <- prizes
            self.vault <- vault
            self.meta = meta
        }

        // addNewBidder adds a new Bidder resource to the auction
        access(contract) fun addNewBidder(_ bidder: @Bidder) {
            let oldBidder <- self.bidders[bidder.address] <- bidder
            destroy oldBidder
        }

        // bidderExist returns false if there is no Bidder resource for the
        // provided address, otherwise it returns true
        access(contract) fun bidderExists(_ address: Address): Bool {
            if self.bidders[address] == nil {
                return false
            } else {
                return true
            }
        }
        
        // getBidders returns a dictionary with the bidder's address and
        // bidTotal
        access(contract) fun getBidders(): {Address: UFix64} {
            let bidders = &self.bidders as &{Address: Bidder}
            let dictionary: {Address: UFix64} = {}
            
            for address in bidders.keys {
                let bidder = &bidders[address] as &Bidder
                dictionary[address] = bidder.bidTotal
            }
            
            return dictionary
        }

        destroy() {
            // TODO: Safely destroy the auction resources by sending
            // FTs and NFTs back to their owners
            destroy self.bidders
            destroy self.prizes
            destroy self.vault
        }
    }

    // Meta contains the metadata for an Auction
    pub struct Meta {

        // Auction Settings
        pub let auctionID: UInt64
        pub let totalSessions: UInt64
        pub let sessionLengthInBlocks: UInt64

        // Auction State
        pub(set) var sessionStartBlock: UInt64
        pub(set) var currentSession: UInt64
        pub(set) var auctionCompleted: Bool

        init(
            auctionID: UInt64,
            totalSessions: UInt64,
            sessionLengthInBlocks: UInt64
        ) {
            self.auctionID = auctionID
            self.totalSessions = totalSessions
            self.sessionLengthInBlocks = sessionLengthInBlocks
            self.sessionStartBlock = getCurrentBlock().height
            self.currentSession = UInt64(1)
            self.auctionCompleted = false
        }
    }

    pub resource Bidder {

        // Address
        pub let address: Address

        // Capabilities
        pub let vaultCap: Capability<&{FungibleToken.Receiver}>
        pub let collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>

        // Meta
        pub var bidTotal: UFix64
        pub var bidPosition: UInt

        init(
            address: Address,
            vaultCap: Capability<&{FungibleToken.Receiver}>,
            collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>,
            bidTotal: UFix64
        ) {
            self.address = address
            self.vaultCap = vaultCap
            self.collectionCap = collectionCap
            self.bidTotal = bidTotal
            self.bidPosition = 0
        }
        
        // increaseTotal adds the provided amount to the bidder's bidTotal
        access(contract) fun increaseTotal(amount: UFix64) {
            self.bidTotal = self.bidTotal + amount
        }
    }

    pub resource AuctionCollection: AuctionCollectionPublic {
        // The total amount of Auctions in the AuctionCollection
        access(contract) var totalAuctions: UInt64

        // Auctions
        access(contract) var auctions: @{UInt64: Auction}

        init() {
            self.totalAuctions = UInt64(0)
            self.auctions <- {}
        }

        // createNewAuction initializes a new Auction resource with prizes, auction
        // settings and required metadata
        pub fun createNewAuction(
            totalSessions: UInt64,
            sessionLengthInBlocks: UInt64,
            prizes: @[NonFungibleToken.NFT],
            vault: @FungibleToken.Vault
        ) {

            let auctionID = self.totalAuctions + UInt64(1)
            
            // Create auction Meta
            let AuctionMeta = Meta(
                auctionID: auctionID,
                totalSessions: totalSessions,
                sessionLengthInBlocks: sessionLengthInBlocks
            )
            
            // Create Auction resource
            let Auction <- create Auction(
                prizes: <- prizes,
                meta: AuctionMeta,
                vault: <-vault
            )
            
            let oldToken <- self.auctions[auctionID] <- Auction
            destroy oldToken

            emit NewAuctionCreated(id: auctionID, totalSessions: totalSessions)
        }

        // borrowAuction returns a reference to the Auction with the
        // provided ID
        pub fun borrowAuction(_ id: UInt64): &Auction {
            return &self.auctions[id] as &Auction
        }

        // newBid creates a new Bidder resource, adds it to the Auction and deposits
        // the bidder's tokens into the Auction vault
        pub fun placeBid(
            auctionID: UInt64,
            vaultCap: Capability<&{FungibleToken.Receiver}>,
            collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>,
            bidTokens: @FungibleToken.Vault,
            address: Address
        ) {
            // Get the auction reference
            let auctionRef = self.borrowAuction(auctionID)

            // If the bidder has already bid...
            if auctionRef.bidderExists(address) {

                // ...increase the existing Bidder's total
                let bidderRef = &auctionRef.bidders[address] as &Bidder
                bidderRef.increaseTotal(amount: bidTokens.balance)
            // ... otherwise...
            } else {
                // ... create a new Bidder resource
                let newBidder <- create Bidder(
                    address: address,
                    vaultCap: vaultCap,
                    collectionCap: collectionCap,
                    bidTotal: bidTokens.balance
                )
                // ... add the new bidder to the auction
                auctionRef.addNewBidder(<-newBidder)
            }

            // deposit the bid tokens into the auction Vault
            auctionRef.vault.deposit(from: <-bidTokens)
        }

        // getAuctionInfo returns an array of Auction references that belong to
        // the AuctionCollection
        pub fun getAuctionInfo(): [&Auction] {

            let auctions = self.auctions.keys
            let auctionInfo: [&Auction] = []
            
            for id in auctions {
                auctionInfo.append(self.borrowAuction(id))
            }

            return auctionInfo
        }

        // getAuctionBidders returns a dictionary containing the bidder's address
        // and bid total
        pub fun getAuctionBidders(_ id: UInt64): {Address: UFix64} {
            let auction = self.borrowAuction(id)
            return auction.getBidders()
        }

        destroy() {
            destroy self.auctions
        }
    }

    // createAuctionCollection returns a new AuctionCollection resource to the caller
    pub fun createAuctionCollection(): @AuctionCollection {
        let AuctionCollection <- create AuctionCollection()

        emit NewCollectionCreated(block: getCurrentBlock().height)

        return <- AuctionCollection
    }

    init() {}   
}
 