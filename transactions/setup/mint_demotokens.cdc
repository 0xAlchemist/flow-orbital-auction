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

transaction(receiver: Address, amount: UFix64) {

    // public Vault reciever references for both accounts
    let vaultReceiver: &{FungibleToken.Receiver}

    let minterRef: &DemoToken.Minter
    
    prepare(signer: AuthAccount) {
        // get the public object for Account 2
        let receiver = getAccount(receiver)

        // retreive the public vault references for both accounts
        self.vaultReceiver = receiver.getCapability(/public/DemoTokenReceiver)!
                                     .borrow<&{FungibleToken.Receiver}>()
                                        ?? panic("Could not borrow owner's vault reference")

        let minterCap = signer.getCapability(/private/DemoTokenMinter)!

        // get the stored Minter reference from account 2
        self.minterRef = signer.borrow<&DemoToken.Minter>(from: /storage/DemoTokenMinter)
            ?? panic("Could not borrow owner's vault minter reference")
    }

    execute {
        // mint tokens for both accounts
        self.vaultReceiver.deposit(from: <-self.minterRef.mintTokens(amount: UFix64(amount)))
        log("Minted new DemoTokens")
    }
}
 