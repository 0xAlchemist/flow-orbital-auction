// This transaction creates an new Auction for the signer
// 

import DemoToken from 0x179b6b1cb6755e31
import NonFungibleToken from 0x01cf0e2f2f715450
import Rocks from 0xf3fcd2c1a78f5eee
import OrbitalAuction from 0xe03daebed8ca0615

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - NonFungibleToken.cdc
// Acct 2 - 0x179b6b1cb6755e31 - DemoToken.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - Rocks.cdc
// Acct 4 - 0xe03daebed8ca0615 - Auction.cdc

transaction {

    prepare(account: AuthAccount) {

        let orbitalRef = account.borrow<&OrbitalAuction.AuctionCollection>(from: /storage/OrbitalAuction)!
        
        let collectionRef = account.borrow<&NonFungibleToken.Collection>(from: /storage/RockCollection)!

        let tempCollection <- Rocks.createEmptyCollection()

        for id in collectionRef.getIDs() {
            let token <- collectionRef.withdraw(withdrawID: id)
            tempCollection.deposit(token: <-token)
        }
        
        orbitalRef.addPrizeCollectionToAuction(UInt64(1), collection: <-tempCollection)

        // store the sale resource in the account for storage
        
    }
}
 