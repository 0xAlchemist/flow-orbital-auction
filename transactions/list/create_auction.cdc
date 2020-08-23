// This transaction creates an new Auction for the signer
// 

import DemoToken from 0x179b6b1cb6755e31
import NonFungibleToken from 0x01cf0e2f2f715450
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

        let tokenIDs = collectionRef.getIDs()

        // var prizes: @[NonFungibleToken.NFT] <- []
        
        // for id in tokenIDs {
        //     prizes.append(<-collectionRef.withdraw(withdrawID: id))
        // }

        let vault <- DemoToken.createEmptyVault()

        // store the sale resource in the account for storage
        orbitalRef.createNewAuction(
            totalEpochs: UInt64(12),
            epochLengthInBlocks: UInt64(30),
            vault: <-vault
        )
    }
}
 