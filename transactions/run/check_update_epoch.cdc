// This transaction pays out tokens to the hardcoded account

import OrbitalAuction from 0xe03daebed8ca0615

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - NonFungibleToken.cdc
// Acct 2 - 0x179b6b1cb6755e31 - DemoToken.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - Rocks.cdc
// Acct 4 - 0xe03daebed8ca0615 - Auction.cdc

transaction(auctionID: UInt64) {

    let auctionRef: &{OrbitalAuction.AuctionAdmin}

    prepare(account: AuthAccount) {

        self.auctionRef = account.borrow<&{OrbitalAuction.AuctionAdmin}>(from: /storage/OrbitalAuction)!
    }

    execute {
        self.auctionRef.checkIsNextEpoch(auctionID)
    }
}