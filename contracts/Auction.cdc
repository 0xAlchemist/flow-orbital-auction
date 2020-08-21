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
    pub resource interface AuctionPublic {
        pub fun placeBid(
            auctionID: UInt64,
            vaultCap: Capability<&{FungibleToken.Receiver}>,
            collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>,
            bidTokens: @FungibleToken.Vault,
            address: Address
        )
        pub fun getAuctionInfo(): [&Auction]
        pub fun getAuctionBidders(_ auctionID: UInt64): {Address: UFix64}
        pub fun logCurrentEpochInfo(_ auctionID: UInt64)
    }

    pub resource interface AuctionAdmin {
        pub fun checkIsNextEpoch(_ auctionID: UInt64)
        pub fun startNewEpoch(_ auctionID: UInt64)
        pub fun sendPayout(_ auctionID: UInt64, epoch: UInt64, address: Address, amount: UFix64)
        pub fun sendPrize(_ auctionID: UInt64, address: Address, epoch: UInt64)
    }

    // Auction contains the Resources and metadata for a single auction
    pub resource Auction {
        /* TODO:
        prizes should be a resource with receiver capability */
        access(contract) var epochs: @{UInt64: Epoch}
        access(contract) var prizes: @[NonFungibleToken.NFT] 
        access(contract) var bidders: {Address: Bidder}
        access(contract) var meta: Meta

        init(epoch: @Epoch, prizes: @[NonFungibleToken.NFT], meta: Meta) {
            self.epochs <- {UInt64(1): <-epoch}
            self.prizes <- prizes
            self.bidders = {}
            self.meta = meta
        }

        pub fun borrowCurrentEpoch(): &Epoch {
            return &self.epochs[self.meta.currentEpoch] as &Epoch
        }

        pub fun borrowEpoch(_ epoch: UInt64): &Epoch {
            return &self.epochs[epoch] as &Epoch
        }

        // addNewBidder adds a new Bidder resource to the auction
        access(contract) fun addNewBidder(_ bidder: Bidder) {
            self.bidders[bidder.address] = bidder
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

        pub fun sendTokensToBidder(address: Address, amount: UFix64) {
            let receiver = &self.bidders[address] as &Bidder
            
            if let vault = receiver.vaultCap.borrow() {
                let epoch = &self.epochs[self.meta.currentEpoch] as &Epoch
                let tokens <- epoch.vault.withdraw(amount: amount)
                vault.deposit(from: <- tokens)
            }
        }

        pub fun sendPrizeToBidder(address: Address, epoch: UInt64) {
            let receiver = &self.bidders[address] as &Bidder

            if let collection = receiver.collectionCap.borrow() {
                let NFT <- self.prizes.remove(at: epoch)
                collection.deposit(token: <-NFT)
            }
        }

        destroy() {
            // TODO: Safely destroy the auction resources by sending
            // FTs and NFTs back to their owners
            destroy self.prizes
        }
    }

    pub resource Epoch {

        pub let id: UInt64
        pub let endBlock: UInt64
        access(contract) let vault: @FungibleToken.Vault

        init(id: UInt64, endBlock: UInt64, vault: @FungibleToken.Vault) {
            self.id = id
            self.endBlock = endBlock
            self.vault <- vault
        }

        destroy() {
            destroy self.vault
        }
    }

    // Meta contains the metadata for an Auction
    pub struct Meta {

        // Auction Settings
        pub let auctionID: UInt64
        pub let totalEpochs: UInt64
        pub let epochLength: UInt64

        // Auction State
        pub(set) var epochStartBlock: UInt64
        pub(set) var currentEpoch: UInt64
        pub(set) var auctionCompleted: Bool

        init(
            auctionID: UInt64,
            totalSessions: UInt64,
            sessionLengthInBlocks: UInt64
        ) {
            self.auctionID = auctionID
            self.totalEpochs = totalSessions
            self.epochLength = sessionLengthInBlocks
            self.epochStartBlock = getCurrentBlock().height
            self.currentEpoch = UInt64(1)
            self.auctionCompleted = false
        }
    }

    pub struct Bidder {

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

    pub resource AuctionCollection: AuctionPublic, AuctionAdmin {
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
            pre {
                totalSessions <= UInt64(15): "maximum 15 sessions"
            }

            let auctionID = self.totalAuctions + UInt64(1)
            
            // Create auction Meta
            let AuctionMeta = Meta(
                auctionID: auctionID,
                totalSessions: totalSessions,
                sessionLengthInBlocks: sessionLengthInBlocks
            )

            let Epoch <- create Epoch(
                id: UInt64(1),
                endBlock: getCurrentBlock().height + sessionLengthInBlocks,
                vault: <-vault
            )
            
            // Create Auction resource
            let Auction <- create Auction(
                epoch: <- Epoch,
                prizes: <- prizes,
                meta: AuctionMeta
            )
            
            let oldToken <- self.auctions[auctionID] <- Auction
            destroy oldToken

            emit NewAuctionCreated(id: auctionID, totalSessions: totalSessions)
        }

        // borrowAuction returns a reference to the Auction with the
        // provided ID
        pub fun borrowAuction(_ auctionID: UInt64): &Auction {
            return &self.auctions[auctionID] as &Auction
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
                let newBidder = Bidder(
                    address: address,
                    vaultCap: vaultCap,
                    collectionCap: collectionCap,
                    bidTotal: bidTokens.balance
                )
                // ... add the new bidder to the auction
                auctionRef.addNewBidder(newBidder)
            }

            // deposit the bid tokens into the auction Vault
            let epoch = auctionRef.borrowCurrentEpoch()
            epoch.vault.deposit(from: <-bidTokens)
        }

        pub fun checkIsNextEpoch(_ auctionID: UInt64) {
            let auctionRef = self.borrowAuction(auctionID)
            let epoch = auctionRef.borrowCurrentEpoch()
            let currentBlock = getCurrentBlock().height

            if currentBlock >= epoch.endBlock {
                self.handleEndOfEpoch(auctionID)
            }
        }

        pub fun handleEndOfEpoch(_ auctionID: UInt64) {
            let auctionRef = self.borrowAuction(auctionID)

            if auctionRef.meta.currentEpoch >= auctionRef.meta.totalEpochs {
                auctionRef.meta.auctionCompleted = true
            } else {
                self.startNewEpoch(auctionID)
            }
        }

        pub fun startNewEpoch(_ auctionID: UInt64) {
            let auctionRef = self.borrowAuction(auctionID)
            let currentEpoch = auctionRef.borrowCurrentEpoch()

            let newEpochID = currentEpoch.id + UInt64(1)
            
            let NewEpoch <- create Epoch(
                id: newEpochID,
                endBlock: getCurrentBlock().height + auctionRef.meta.epochLength,
                vault: <- currentEpoch.vault.withdraw(amount: UFix64(0))
            )

            auctionRef.meta.currentEpoch = newEpochID
            auctionRef.epochs[newEpochID] <-! NewEpoch
        }

        pub fun sendPayout(_ auctionID: UInt64, epoch: UInt64, address: Address, amount: UFix64) {
            let auctionRef = self.borrowAuction(auctionID)
            let epoch = auctionRef.borrowEpoch(epoch)

            if epoch.vault.balance < amount { 
                panic("auction vault balance is less than transaction amount") 
            }

            auctionRef.sendTokensToBidder(address: address, amount: amount)
        }

        pub fun sendPrize(_ auctionID: UInt64, address: Address, epoch: UInt64) {
            let auctionRef = self.borrowAuction(auctionID)
            let epochIndex = epoch - UInt64(1)

            if auctionRef.prizes[epoch] == nil {
                panic("prize does not exist")
            }

            auctionRef.sendPrizeToBidder(address: address, epoch: epoch)
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

        pub fun logCurrentEpochInfo(_ auctionID: UInt64) {
            let auctionRef = self.borrowAuction(auctionID)
            let epoch = auctionRef.borrowCurrentEpoch()

            log("*************")
            log("Current Epoch")
            log(epoch.id)
            log("End Block")
            log(epoch.endBlock)
            log("Vault Balance")
            log(epoch.vault.balance)
            log("*************")
        }

        // getAuctionBidders returns a dictionary containing the bidder's address
        // and bid total
        pub fun getAuctionBidders(_ auctionID: UInt64): {Address: UFix64} {
            let auction = self.borrowAuction(auctionID)
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
 