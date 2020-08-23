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

    // AuctionPublic is a resource interface that restricts users to
    // placing bids and reading data from an Auction instance
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
        pub fun logOrbInfo(auctionID: UInt64, orbID: UInt64)
        pub fun logAllOrbInfo(auctionID: UInt64)
    }

    // AuctionAdmin is a resource interface that provides users
    // with access to restricted Auction methods that may impact
    // the outcome of the auction
    //
    // AuctionAdmin can be used to manage the Auction from an external 
    // script
    //
    pub resource interface AuctionAdmin {
        pub fun checkIsNextEpoch(_ auctionID: UInt64)
        pub fun startNextEpoch(_ auctionID: UInt64)
    }

    // AuctionCollection contains all orbital auctions for an account and provides
    // methods for manipulating and reading data from the auction
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
            totalEpochs: UInt64,
            epochLengthInBlocks: UInt64,
            vault: @FungibleToken.Vault,
            prizes: @NonFungibleToken.Collection
        ) {
            let auctionID = self.totalAuctions + UInt64(1)
            
            // Create auction Meta
            let AuctionMeta = Meta(
                auctionID: auctionID,
                totalEpochs: totalEpochs,
                epochLengthInBlocks: epochLengthInBlocks
            )
            
            // Create Auction resource
            let Auction <- create Auction(
                vault: <- vault,
                meta: AuctionMeta
            )
            
            let oldToken <- self.auctions[auctionID] <- Auction
            destroy oldToken

            self.addPrizeCollectionToAuction(auctionID, collection: <-prizes)
            self.createNewEpoch(auctionID, epochID: UInt64(1))
            self.createNewOrb(auctionID)

            emit NewAuctionCreated(id: auctionID, totalSessions: totalEpochs)
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

            self.checkIsNextEpoch(auctionID)

            // Get the auction reference
            let auctionRef = self.borrowAuction(auctionID)

            // If the bidder has already bid...
            if auctionRef.bidderExists(address) {

                // ...increase the existing Bidder's total
                let bidderRef = &auctionRef.bidders[address] as &Bidder

                let vault = &bidderRef.bidVault as &FungibleToken.Vault

                if vault == nil {

                    auctionRef.addNewBidder(
                        address: address,
                        bidVault: <-bidTokens,
                        vaultCap: vaultCap,
                        collectionCap: collectionCap
                    )

                } else {

                    bidderRef.bidVault.deposit(from: <-bidTokens)

                }

            // ... otherwise...
            } else {
                // ... create a new Bidder resource
                auctionRef.addNewBidder(
                    address: address,
                    bidVault: <-bidTokens,
                    vaultCap: vaultCap,
                    collectionCap: collectionCap
                )
            }
        }

        pub fun getHighestBidder(_ auctionID: UInt64): @Bidder {
            let auctionRef = self.borrowAuction(auctionID)
            let bidders = &auctionRef.bidders as &{Address: Bidder}

            if bidders.length == 0 { log("there are no bidders") }

            var highestBidderAddress = bidders.keys[0] 

            for address in bidders.keys {
                let highBidder = &bidders[highestBidderAddress] as &Bidder
                let checkedBidder = &bidders[address] as &Bidder

                if checkedBidder.bidVault.balance > highBidder.bidVault.balance {
                    highestBidderAddress = address
                }
            }
            
            let highestBidder <- bidders[highestBidderAddress] <- nil

            return <- highestBidder!
        }

        pub fun checkIsNextEpoch(_ auctionID: UInt64) {
            let auctionRef = self.borrowAuction(auctionID)
            let epoch = auctionRef.borrowCurrentEpoch()
            let currentBlock = getCurrentBlock().height

            if currentBlock >= epoch.endBlock {
                if !auctionRef.meta.auctionCompleted {
                    self.handleEndOfEpoch(auctionID)
                }
            }
        }

        pub fun handleEndOfEpoch(_ auctionID: UInt64) {
            let auctionRef = self.borrowAuction(auctionID)

            log("handleEndOfEpoch")
            log(auctionRef.getBidders())

            // TODO: Handle case if there are no bids?
            let orb = auctionRef.borrowOrb(auctionRef.meta.currentEpoch)
            let highestBidder <- self.getHighestBidder(auctionID)
            let bidAmount = highestBidder.bidVault.balance

            let bidderTokens <- highestBidder.bidVault.withdraw(amount: bidAmount)

            auctionRef.distributeBidTokens(<-bidderTokens)

            orb.assignOwner(bidder: <-highestBidder)

            self.logCurrentEpochInfo(auctionID)

            if auctionRef.meta.currentEpoch >= auctionRef.meta.totalEpochs {

                auctionRef.meta.auctionCompleted = true

            } else {

                self.startNextEpoch(auctionID)
                self.createNewOrb(auctionID)
            }
        }

        pub fun startNextEpoch(_ auctionID: UInt64) {
            let auctionRef = self.borrowAuction(auctionID)
            let currentEpoch = auctionRef.borrowCurrentEpoch()

            let newEpochID = currentEpoch.id + UInt64(1)
            
            self.createNewEpoch(auctionID, epochID: newEpochID)
            auctionRef.meta.currentEpoch = newEpochID
        }

        pub fun createNewEpoch(_ auctionID: UInt64, epochID: UInt64) {
            let auctionRef = self.borrowAuction(auctionID)

            let endBlock = getCurrentBlock().height + auctionRef.meta.epochLength

            let newEpoch = Epoch(id: epochID, endBlock: endBlock)

            auctionRef.epochs[newEpoch.id] = newEpoch
        }

        pub fun createNewOrb(_ auctionID: UInt64) {
            let auctionRef = self.borrowAuction(auctionID)
            let currentEpoch = auctionRef.meta.currentEpoch

            let newOrb <- create Orb(
                id: currentEpoch,
                vault: <-auctionRef.masterVault.withdraw(amount: UFix64(0))
            )

            let oldOrb <- auctionRef.orbs[currentEpoch] <- newOrb
            destroy oldOrb

            self.addPrizeToOrb(auctionID, orbID: currentEpoch)
        }

        pub fun addPrizeToAuction(_ auctionID: UInt64, prize: @NonFungibleToken.NFT) {
            let auctionRef = self.borrowAuction(auctionID)
            let prizeID = UInt64(auctionRef.prizes.length + 1)

            auctionRef.prizes[prizeID] <-! prize
        }

        pub fun addPrizeCollectionToAuction(_ auctionID: UInt64, collection: @NonFungibleToken.Collection) {

            for tokenID in collection.getIDs() {
                let token <- collection.withdraw(withdrawID: tokenID)
                self.addPrizeToAuction(auctionID, prize: <-token)
            }

            destroy collection
        }

        pub fun addPrizeToOrb(_ auctionID: UInt64, orbID: UInt64) {
            let auctionRef = self.borrowAuction(auctionID)
            let orbRef = &auctionRef.orbs[orbID] as &Orb

            if orbRef == nil {
                panic("Orb doesn't exist yet")
            }

            if let prize <- auctionRef.prizes[orbID] <- nil {
                orbRef.assignPrize(prize: <-prize)
            } else {
                log("no prize available for this epoch")
            }
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
            let orb = auctionRef.borrowOrb(auctionRef.meta.currentEpoch)

            log("*************")
            log("Current Epoch")
            log(epoch.id)
            log("Current Block")
            log(getCurrentBlock().height)
            log("End Block")
            log(epoch.endBlock)
            log("Distribution")
            log(epoch.distribution)
        }

        pub fun logOrbInfo(auctionID: UInt64, orbID: UInt64) {
            let auctionRef = self.borrowAuction(auctionID)
            let orb = auctionRef.borrowOrb(orbID)
            
            log("*************")
            log("Orb ID")
            log(orb.id)
            log("***")
            if let orbOwner = orb.bidder?.address {
                log("Orb Owner")
                log(orbOwner)
            } else {
                log("Orb is unowned")
            }
            log("***")
            log("Orb Balance")
            log(orb.vault.balance)
            if orb.hasPrize() {
                log("Orb Prize")
                log(orb)
            } else {
                log("Orb has no prize yet")
            }
        }

        pub fun logAllOrbInfo(auctionID: UInt64) {
            let auctionRef = self.borrowAuction(auctionID)
            let orbs = auctionRef.orbs.keys

            for id in orbs {
                let orb = self.logOrbInfo(auctionID: auctionID, orbID: id)
            }
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

    // Auction contains the Resources and metadata for a single auction
    pub resource Auction {
        access(contract) var epochs: {UInt64: Epoch}
        access(contract) var orbs: @{UInt64: Orb}
        access(contract) let masterVault: @FungibleToken.Vault
        access(contract) var bidders: @{Address: Bidder}
        access(contract) var prizes: @{UInt64: NonFungibleToken.NFT}
        access(contract) var meta: Meta

        init(vault: @FungibleToken.Vault, meta: Meta) {
            self.epochs = {}
            self.orbs <- {}
            self.masterVault <- vault
            self.bidders <- {}
            self.prizes <- {}
            self.meta = meta
        }

        pub fun borrowOrb(_ orbID: UInt64): &Orb {
            return &self.orbs[orbID] as &Orb
        }

        pub fun borrowCurrentEpoch(): &Epoch {
            return &self.epochs[self.meta.currentEpoch] as &Epoch
        }

        pub fun borrowEpoch(_ epoch: UInt64): &Epoch {
            return &self.epochs[epoch] as &Epoch
        }

        // addNewBidder adds a new Bidder resource to the auction
        access(contract) fun addNewBidder(
            address: Address,
            bidVault: @FungibleToken.Vault,
            vaultCap: Capability<&{FungibleToken.Receiver}>,
            collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>) {
            
            let bidder <- create Bidder(
                address: address,
                bidVault: <-bidVault,
                vaultCap: vaultCap,
                collectionCap: collectionCap
            )

            self.bidders[address] <-! bidder
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

        access(contract) fun distributeBidTokens(_ vault: @FungibleToken.Vault) {
            let initialBalance = vault.balance
            let epoch = self.borrowCurrentEpoch()
            let weights = epoch.distribution.weights

            for id in weights.keys {
                let orb = self.borrowOrb(id)
                let withdrawAmount = initialBalance * weights[id]!
                let tokens <- vault.withdraw(amount: withdrawAmount)

                orb.vault.deposit(from: <-tokens)
            }

            destroy vault
        }
        
        // getBidders returns a dictionary with the bidder's address and
        // bidTotal
        access(contract) fun getBidders(): {Address: UFix64} {
            let bidders = &self.bidders as &{Address: Bidder}
            let dictionary: {Address: UFix64} = {}
            
            for address in bidders.keys {
                let bidder = &bidders[address] as &Bidder
                dictionary[address] = bidder.bidVault.balance
            }
            
            return dictionary
        }


        destroy() {
            // TODO: Safely destroy the auction resources by sending
            // FTs and NFTs back to their owners
            destroy self.orbs
        }
    }

    // Orb contains the prizes from the auction as well as the Bidder
    // that eventually owns it
    pub resource Orb {
        pub let id: UInt64
        pub var bidder: @Bidder?
        pub var prize: @NonFungibleToken.NFT?
        pub var vault: @FungibleToken.Vault

        init(id: UInt64, vault: @FungibleToken.Vault) {
            self.id = id
            self.bidder <- nil
            self.prize <- nil
            self.vault <- vault
        }

        access(contract) fun assignOwner(bidder: @Bidder) {
            pre {
                self.bidder == nil: "Orb already has an owner"
            }
            self.bidder <-! bidder
        }

        access(contract) fun assignPrize(prize: @NonFungibleToken.NFT) {
            pre {
                self.prize == nil: "Orb already has a prize"
            }
            self.prize <-! prize
        }

        access(contract) fun hasPrize(): Bool {
            if self.prize == nil {
                return false
            } else {
                return true
            }
        }

        pub fun logOwner() {
            log(self.bidder?.address)
        }

        destroy() {
            destroy self.bidder
            destroy self.prize
            destroy self.vault
        }
    }

    // Bidder contains a Vault and the capabilities used to send
    // prizes to the Bidder
    pub resource Bidder {

        // Address
        pub let address: Address

        // Bid Vault
        pub let bidVault: @FungibleToken.Vault

        // Capabilities
        pub let vaultCap: Capability<&{FungibleToken.Receiver}>
        pub let collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>

        init(
            address: Address,
            bidVault: @FungibleToken.Vault,
            vaultCap: Capability<&{FungibleToken.Receiver}>,
            collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>
        ) {
            self.address = address
            self.bidVault <- bidVault
            self.vaultCap = vaultCap
            self.collectionCap = collectionCap
        }

        destroy() {
            destroy self.bidVault
        }
    }

    // Meta contains the metadata for an Auction
    pub struct Meta {

        // Auction Settings
        pub let auctionID: UInt64
        pub let totalEpochs: UInt64
        pub let epochLength: UInt64

        // Auction State
        pub(set) var currentEpoch: UInt64
        pub(set) var auctionCompleted: Bool

        init(
            auctionID: UInt64,
            totalEpochs: UInt64,
            epochLengthInBlocks: UInt64
        ) {
            self.auctionID = auctionID
            self.totalEpochs = totalEpochs
            self.epochLength = epochLengthInBlocks
            self.currentEpoch = UInt64(1)
            self.auctionCompleted = false
        }
    }

    // Epoch represents a single cycle in the auction and contains the
    // weights used to distribute the tokens at the end of the cycle
    pub struct Epoch {

        pub let id: UInt64
        pub let endBlock: UInt64
        pub var distribution: Distribution

        init(id: UInt64, endBlock: UInt64) {
            self.id = id
            self.endBlock = endBlock
            self.distribution = Distribution(id)
        }
    }

    // Distribution calculates the weights used to distribute the tokens
    // at the end of an Epoch cycle
    pub struct Distribution {

        pub(set) var weights: {UInt64: UFix64}
        pub(set) var sumFactors: UInt64
        pub(set) var sqrtVal: UInt64

        init(_ session: UInt64) {
            self.weights = {}
            self.sumFactors = 0
            self.sqrtVal = 0

            self.updateFields(session)
        }

        pub fun updateFields(_ n: UInt64) {
            self.sqrtVal = self.sqrt(n)
            self.sumFactors = self.sumOfFactors(n)
            self.weights = self.getWeights(n)
        }

        pub fun getWeights(_ n: UInt64): {UInt64: UFix64} {
            var weights: {UInt64: UFix64} = {}
            var i = UInt64(1)

            while i < n + UInt64(1) {
                if n % i == UInt64(0) {
                    weights[i] = (UFix64(i) / UFix64(self.sumFactors))
                }
                i = i + UInt64(1)
            }
            return weights
        }

        pub fun sumOfFactors(_ n: UInt64): UInt64 {
            if n == UInt64(1) {
                return n
            }

            // sum of divisors
            var res = UInt64(0)
            var i = UInt64(2)

            while i <= self.sqrtVal {

                if n % i == UInt64(0) {
                    if i == (n / i) {
                        res = res + i
                    } else {
                        res = res + (i + n/i)
                    }
                }

                i = i + UInt64(1)
            }

            res = res + n + UInt64(1)
            return res
        }

        pub fun sqrt(_ n: UInt64): UInt64 {
            if n == UInt64(0) {
                return n
            }

            if n == UInt64(1) {
                return n
            }

            var i = UInt64(1)
            var res = UInt64(1)

            while res <= n {
                i = i + UInt64(1)
                res = i * i
            }

            return i - UInt64(1)
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
 