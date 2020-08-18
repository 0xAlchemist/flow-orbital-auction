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
    // pub event NewBid(tokenID: UInt64, bidPrice: UFix64)
    // pub event AuctionSettled(tokenID: UInt64, price: UFix64)

    // AuctionPublic is a resource interface that restricts users to...
    //
    pub resource interface AuctionCollectionPublic {
        pub fun getAuctionInfo()
    }

    // Auction contains the Resources and metadata for a single auction
    pub resource Auction {
        access(contract) var totalBidders: UInt64
        // TODO: Add Fields
        access(contract) var bidders: @{UInt64: Bidder}
        access(contract) var prizes: @[NonFungibleToken.NFT]
        access(contract) var meta: Meta?

        init(prizes: @[NonFungibleToken.NFT], meta: Meta) {
            self.totalBidders = UInt64(0)
            self.bidders <- {}
            self.prizes <- prizes
            self.meta = meta
        }

        destroy() {
            // TODO: Safely destroy the auction resources by sending
            // FTs and NFTs back to their owners
            destroy self.bidders
            destroy self.prizes
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

        // Capabilities
        pub let vaultCap: Capability<&{FungibleToken.Receiver}>
        pub let collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>

        // Meta
        access(contract) var bidTotal: UFix64
        access(contract) var bidPosition: Int

        init(
            vaultCap: Capability<&{FungibleToken.Receiver}>,
            collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>
        ) {
            self.vaultCap = vaultCap
            self.collectionCap = collectionCap
            self.bidTotal = UFix64(0)
            self.bidPosition = 0
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
            prizes: @[NonFungibleToken.NFT]
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
                meta: AuctionMeta
            )
            
            let oldToken <- self.auctions[auctionID] <- Auction
            destroy oldToken

            emit NewAuctionCreated(id: auctionID, totalSessions: totalSessions)
        }

        pub fun getAuctionInfo() {
            let auctions = self.auctions.keys

            for id in auctions {
                let auctionRef = &self.auctions[id] as &Auction
                log(auctionRef)
            }
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
 