const {assert, expect} = require('chai')
const { deployDiamond } = require('../scripts/deploy')
const { deployCollection } = require('../scripts/deployCollection')

describe('Canary protocol test', async function(){
    let diamondAddress
    let collectionAddress
    let canaryFacet
    let collection
    let owner
    let accounts
    let rights

    before(async function(){
        diamondAddress = await deployDiamond()
        canaryFacet = await ethers.getContractAt('CanaryFacet', diamondAddress)
        collectionAddress = await deployCollection()
        collection = await ethers.getContractAt('Dungeon', collectionAddress)
        accounts = await ethers.getSigners()
        owner = accounts[0]
        
        let tx
        
        tx = await collection.createCollectible("ipfs://bafkreihxwh3yekjq2bakdje4okxpdlsdqlua4jur4iogv2kbyzr6lnawkm")
        await tx.wait()

        tx = await collection.createCollectible("ipfs://bafkreihps5wq65dnaqxs4tgefoqy3qceqm7yl6x3cc7m4ztdqvrflskg2e")
        await tx.wait()

        tx = await collection.createCollectible("ipfs://bafkreiagwvhiyoo3hmoglboczeexmphmnrelrh4dvbfh6agjm3oqewfoya")
        await tx.wait()

        tx = await collection.approve(diamondAddress, '0')
        await tx.wait()
        tx = await collection.approve(diamondAddress, '1')
        await tx.wait()
        tx = await collection.approve(diamondAddress, '2')
        await tx.wait()

        tx = await canaryFacet.depositNFT(collectionAddress, '0', '3000000000000000', '30', '10')
        await tx.wait()
        tx = await canaryFacet.depositNFT(collectionAddress, '1', '9000000000000000', '30', '10')
        await tx.wait()
        tx = await canaryFacet.depositNFT(collectionAddress, '2', '20000000000000000', '30', '1')
        await tx.wait()
        rights = await canaryFacet.getAvailableNFTs()
    })

    it('should test the deposit of NFTs into the protocol', async function(){
        
        let NFTOwner
        
        assert.equal(rights.length, 3)
        NFTOwner = await canaryFacet.ownerOf(rights[0])        
        assert.equal(NFTOwner, owner.address)
        NFTOwner = await canaryFacet.ownerOf(rights[1])        
        assert.equal(NFTOwner, owner.address)
        NFTOwner = await canaryFacet.ownerOf(rights[2])        
        assert.equal(NFTOwner, owner.address)

        let availableRights
        availableRights = await canaryFacet.availableRightsOf(rights[0])
        assert.equal(availableRights, 10)
        availableRights = await canaryFacet.availableRightsOf(rights[1])
        assert.equal(availableRights, 10)
        availableRights = await canaryFacet.availableRightsOf(rights[2])
        assert.equal(availableRights, 1)

        let rightsPrice
        rightsPrice = await canaryFacet.dailyPriceOf(rights[0])
        assert.equal(rightsPrice, '3000000000000000')
        rightsPrice = await canaryFacet.dailyPriceOf(rights[1])
        assert.equal(rightsPrice, '9000000000000000')
        rightsPrice = await canaryFacet.dailyPriceOf(rights[2])
        assert.equal(rightsPrice, '20000000000000000')     
        
        let maxPeriod
        maxPeriod = await canaryFacet.maxPeriodOf(rights[0])
        assert.equal(maxPeriod, 30)
        maxPeriod = await canaryFacet.maxPeriodOf(rights[1])
        assert.equal(maxPeriod, 30)
        maxPeriod = await canaryFacet.maxPeriodOf(rights[2])
        assert.equal(maxPeriod, 30)

        let origin = []
        origin = await canaryFacet.originOf(rights[0])
        assert.equal('0x'+origin[0].substring(26), collectionAddress.toLowerCase())
        assert.equal(Number(origin[1]), 0)
        origin = await canaryFacet.originOf(rights[1])
        assert.equal('0x'+origin[0].substring(26), collectionAddress.toLowerCase())
        assert.equal(Number(origin[1]), 1)
        origin = await canaryFacet.originOf(rights[2])
        assert.equal('0x'+origin[0].substring(26), collectionAddress.toLowerCase())
        assert.equal(Number(origin[1]), 2)
    })

    it('should test the getRights method', async function(){
        let tx
        let dailyPrice
        await expect(
            canaryFacet.getRights('00000000000000000000000000000000000000000000000000000000000000000000', '10', {value: '0'})
        ).to.be.revertedWith('NFT is not available')
        dailyPrice = await canaryFacet.dailyPriceOf(rights[0])
        await expect(
            canaryFacet.getRights(rights[0], '31', {value: `${Number(dailyPrice)*31}`})
        ).to.be.revertedWith('period is above the max period')
        await expect(
            canaryFacet.getRights(rights[0], '10', {value: `${Number(dailyPrice)*9}`})
        ).to.be.revertedWith('value is less than the required')

        dailyPrice = await canaryFacet.dailyPriceOf(rights[2])
        tx = await canaryFacet.connect(accounts[1]).getRights(rights[2], '30', {value: `${Number(dailyPrice)*30}`})
        await tx.wait()

        await expect(
            canaryFacet.connect(accounts[2]).getRights(rights[2], '30', {value: `${Number(dailyPrice)*30}`})
        ).to.be.revertedWith('limit of right holders reached')

        dailyPrice = await canaryFacet.dailyPriceOf(rights[1])
        tx = await canaryFacet.connect(accounts[1]).getRights(rights[1], '30', {value: `${Number(dailyPrice)*30}`})
        await tx.wait()

        await expect(
            canaryFacet.connect(accounts[1]).getRights(rights[1], '30', {value: `${Number(dailyPrice)*30}`})
        ).to.be.revertedWith('already buy this right')

        await expect(
            canaryFacet.getRights(rights[1], '0', {value: `${Number(dailyPrice)*30}`})
        ).to.be.revertedWith('period is equal to 0')

        let rightsOf
        rightsOf = await canaryFacet.rightsOf(accounts[1].address)
        assert.equal(rightsOf[0].value, rights[2].value)
    })

    it('should test the setAvailability function', async function(){
        let availability
        availability = await canaryFacet.availabilityOf(rights[1])
        assert.equal(availability, true)
        await expect(
            canaryFacet.connect(accounts[1]).setAvailability(rights[1], false,'1')
        ).to.be.revertedWith('only the NFT Owner')
        
        await expect(
            canaryFacet.setAvailability(rights[1], false,'2')
        ).to.be.revertedWith('wrong index for rightid')

        let aux = rights[1]
        let tx
        tx = await canaryFacet.setAvailability(rights[1], false,'1')
        await tx.wait()

        rights = await canaryFacet.getAvailableNFTs()
        assert.equal(rights.length, 2)

        availability = await canaryFacet.availabilityOf(aux)
        assert.equal(availability, false)

        // in this case the index doesn't matter
        tx = await canaryFacet.setAvailability(aux, true,'0')
        await tx.wait()

        rights = await canaryFacet.getAvailableNFTs()
        assert.equal(rights.length, 3)

        availability = await canaryFacet.availabilityOf(rights[2])
        assert.equal(availability, true)

        assert.equal(aux.value, rights[2].value)
    })

    it('should test the withdrawRoyalties function', async function(){
        let tx
        let dailyPrice
        let rightHolders
        dailyPrice = await canaryFacet.dailyPriceOf(rights[0])

        tx = await canaryFacet.connect(accounts[1]).getRights(rights[0], '1', {value: `${Number(dailyPrice)*1}`})
        await tx.wait()
        rightHolders = await canaryFacet.rightHoldersOf(rights[0])
        assert.equal(accounts[1].address, rightHolders[0])

        tx = await canaryFacet.connect(accounts[2]).getRights(rights[0], '3', {value: `${Number(dailyPrice)*3}`})
        await tx.wait()
        rightHolders = await canaryFacet.rightHoldersOf(rights[0])
        assert.equal(accounts[2].address, rightHolders[0])

        tx = await canaryFacet.connect(accounts[3]).getRights(rights[0], '5', {value: `${Number(dailyPrice)*5}`})
        await tx.wait()
        rightHolders = await canaryFacet.rightHoldersOf(rights[0])
        assert.equal(accounts[3].address, rightHolders[0])

        var currentDateTime = new Date();
        await network.provider.send("evm_setNextBlockTimestamp", [(currentDateTime.getTime()/ 1000) + (86400 * 30)])
        await network.provider.send("evm_mine")
        const latestBlock = await ethers.provider.getBlock("latest")
        // console.log(latestBlock.timestamp)

        let deadlineList = []
        let rhindexes = []
        let roIndexes = []
        let confirmedRoyalties = 0
        let i = 0
        // console.log(rightHolders)
        for(rh of rightHolders){
            let deadline = await canaryFacet.holderDeadline(rights[0], rh)
            let rightsPeriod = await canaryFacet.rightsPeriodOf(rights[0], rh)

            if(Number(deadline) < Number(latestBlock.timestamp)){
                deadlineList.push(rh)
                rhindexes.push(i)
                confirmedRoyalties += Number(dailyPrice) * Number(rightsPeriod)
                let rightsOver = await canaryFacet.rightsOf(rh) 
                let j = 0
                // console.log(rightsOver)
                for(ro of rightsOver){
                    if(ro.value === rights[0].value){
                        roIndexes.push(j)
                        
                    }
                    j++
                }
            }
            i++
        }
        // console.log(roIndexes)
        tx = await canaryFacet.withdrawRoyalties(rights[0], deadlineList, roIndexes, rhindexes)
        await tx.wait()
        // console.log(confirmedRoyalties)
    })
})