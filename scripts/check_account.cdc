// This script checks an account's Vault balance and NFT collection
//
import FungibleToken from 0xee82856bf20e2aa6
import NonFungibleToken from 0x01cf0e2f2f715450

// Contract Deployment:
// Acct 1 - 0x01cf0e2f2f715450 - onflow/NonFungibleToken.cdc
// Acct 2 - 0x179b6b1cb6755e31 - demo-token.cdc
// Acct 3 - 0xf3fcd2c1a78f5eee - rocks.cdc
// Acct 4 - 0xe03daebed8ca0615 - auction.cdc

pub fun main(account: Address) {
    // get the accounts' public address objects
    let account = getAccount(account)

    // get the reference to the account's receivers
    // by getting their public capability
    // and borrowing a reference from the capability

    let balanceCap = account.getCapability(/public/DemoTokenBalance)!
    let balanceRef = balanceCap.borrow<&{FungibleToken.Balance}>()!
    let balance = balanceRef.balance

    let collectionCap = account.getCapability(/public/RockCollection)!
    let collectionRef = collectionCap.borrow<&{NonFungibleToken.CollectionPublic}>()!
    let collection = collectionRef.getIDs()

    log("********************")
    log("Account balance for")
    log(account.address)
    log("********************")
    log(balance)
    log("********************")
    log("NFTs in collection")
    log("********************")
    log(collection)
}