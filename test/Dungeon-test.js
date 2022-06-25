const {deployCollection} = require('../scripts/deployCollection.js')

const {assert} = require('chai')

describe('Dungeon collection test', async function () {
    let collectionAddress
    let collection
    let owner
    before(async function (){
        collectionAddress = await deployCollection()
        let accounts = await ethers.getSigners()
        collection = await ethers.getContractAt('Dungeon', collectionAddress)
        owner = accounts[0]
    })

    it("should test the createCollectible and tokenURI function", async () => {
        let tx
        let receipt
        tx = await collection.createCollectible("ipfs://bafkreihxwh3yekjq2bakdje4okxpdlsdqlua4jur4iogv2kbyzr6lnawkm")
        receipt = await tx.wait()

        tx = await collection.createCollectible("ipfs://bafkreihps5wq65dnaqxs4tgefoqy3qceqm7yl6x3cc7m4ztdqvrflskg2e")
        receipt = await tx.wait()

        tx = await collection.createCollectible("ipfs://bafkreiagwvhiyoo3hmoglboczeexmphmnrelrh4dvbfh6agjm3oqewfoya")
        receipt = await tx.wait()

        let first = await collection.tokenURI("0")
        let second = await collection.tokenURI("1")
        let third = await collection.tokenURI("2")

        assert.equal(first, "ipfs://bafkreihxwh3yekjq2bakdje4okxpdlsdqlua4jur4iogv2kbyzr6lnawkm")
        assert.equal(second, "ipfs://bafkreihps5wq65dnaqxs4tgefoqy3qceqm7yl6x3cc7m4ztdqvrflskg2e")
        assert.equal(third, "ipfs://bafkreiagwvhiyoo3hmoglboczeexmphmnrelrh4dvbfh6agjm3oqewfoya")
    })

})