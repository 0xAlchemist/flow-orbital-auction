// This transaction mints tokens for Accounts 1 and 2 using
// the minter stored on Account 1.

// Signer: Account 1 - 0x01cf0e2f2f715450

import FungibleToken from 0xee82856bf20e2aa6
import DemoToken from 0x179b6b1cb6755e31

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - onflow/NonFungibleToken.cdc
// Acct 2 - 0x179b6b1cb6755e31 - demo-token.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - rocks.cdc
// Acct 4 - 0xe03daebed8ca0615 - auction.cdc

transaction(allowedAmount: UFix64) {

    // reference to the DemoToken administrator
    let adminRef: &DemoToken.Administrator
    
    prepare(signer: AuthAccount) {               
        
        // borrow a reference to the Administrator resource in Account 2
        self.adminRef = signer.borrow<&DemoToken.Administrator>(from: /storage/DemoTokenAdmin)
                            ?? panic("Signer is not the token admin!")
        
        // create a new minter and store it in account storage
        let minter <-self.adminRef.createNewMinter(allowedAmount: allowedAmount)
        signer.save<@DemoToken.Minter>(<-minter, to: /storage/DemoTokenMinter)

        // create a capability for the new minter
        let minterRef = signer.link<&DemoToken.Minter>(
            /private/DemoTokenMinter,
            target: /storage/DemoTokenMinter
        )

        log("New DemoToken minter created")
    }
}
 