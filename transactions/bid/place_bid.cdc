// This transaction creates an new Auction for the signer
// 

import FungibleToken from 0xee82856bf20e2aa6
import NonFungibleToken from 0x01cf0e2f2f715450
import DemoToken from 0x179b6b1cb6755e31
import Rocks from 0xf3fcd2c1a78f5eee
import OrbitalAuction from 0xe03daebed8ca0615

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - NonFungibleToken.cdc
// Acct 2 - 0x179b6b1cb6755e31 - DemoToken.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - Rocks.cdc
// Acct 4 - 0xe03daebed8ca0615 - Auction.cdc

transaction {
    let collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>
    let publicVaultCap: Capability<&{FungibleToken.Receiver}>
    let bidTokens: @FungibleToken.Vault
    let bidderAddress: Address

    prepare(account: AuthAccount) {
        
        self.collectionCap = account.getCapability<&{NonFungibleToken.CollectionPublic}>(/public/RockCollection)!
        // check that the capability is linked
        if self.collectionCap.check() == nil {
            panic("new_bid.cdc: collection cap is not linked")
        }
        
        self.publicVaultCap = account.getCapability<&{FungibleToken.Receiver}>(/public/DemoTokenReceiver)!
        // check that the capability is linked
        if self.publicVaultCap.check() == nil {
            panic("new_bid.cdc: collection cap is not linked")
        }


        let adminVaultRef = account.borrow<&FungibleToken.Vault>(from: /storage/DemoTokenVault)!

        self.bidTokens <- adminVaultRef.withdraw(amount: UFix64(20))

        self.bidderAddress = account.address
    }

    execute {
        // get the public account object where the auction capability is stored
        let seller = getAccount(0x179b6b1cb6755e31)

        // get the public reference to the AuctionCollection
        let auctionCap = seller.getCapability(/public/OrbitalAuction)!

        if auctionCap.check<&{OrbitalAuction.AuctionCollectionPublic}>() == nil {
            panic("new_bid.cdc: seller has no auction available")
        }

        let auctionRef = auctionCap.borrow<&{OrbitalAuction.AuctionCollectionPublic}>()!

        auctionRef.placeBid(
            auctionID: UInt64(1),
            vaultCap: self.publicVaultCap,
            collectionCap: self.collectionCap,
            bidTokens: <-self.bidTokens,
            address: self.bidderAddress
        )
    }
}
 