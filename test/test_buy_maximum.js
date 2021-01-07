const IdoDFY = artifacts.require("./IdoDFY.sol")
const DFY = artifacts.require("./DFY.sol")
const ERC20CustomToken = artifacts.require("./ERC20CustomToken.sol")
const Web3 = require('web3')
const web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'))
const BigNumber = require('bignumber.js');

contract('IdoDFY contract: Buy IDO Max amount', function (accounts) {
    let owner = accounts[0]
    let ownerBTC = accounts[1]
    let ownerETH = accounts[2]
    let DFYContract, DFYContractAddress, idoDFYContract, idoDFYContractAddress
    let ETHContract, ETHContractAddress, BTCContact, BTCContractAddress

    const address0 = "0x0000000000000000000000000000000000000000"
    before("setup", async function () {

        DFYContract = await DFY.new({from: owner})
        DFYContractAddress = DFYContract.address
        console.log('\t' + DFYContractAddress)

        idoDFYContract = await IdoDFY.new(DFYContract.address, {from: owner})
        idoDFYContractAddress = idoDFYContract.address
        console.log('\t' + idoDFYContractAddress)

        ETHContract = await ERC20CustomToken.new("Ethereum", "ETH", {from: ownerETH})
        ETHContractAddress = ETHContract.address
        console.log('\t' + ETHContractAddress)

        BTCContact = await ERC20CustomToken.new("Bitcoin", "BTC", {from: ownerBTC})
        BTCContractAddress = BTCContact.address
        console.log('\t' + BTCContractAddress)

        await DFYContract.enableTransfer({from: owner})
        await DFYContract.transfer(idoDFYContractAddress, BigNumber(170000000 * Math.pow(10, 18)), {from: owner})
    });

    it("Buy IDO using BTC step 1", async () => {
        await idoDFYContract.updateExchangePair(BTCContractAddress, 170000, 1, {from: owner})
        await idoDFYContract.updateExchangePair(ETHContractAddress, 2000, 1, {from: owner})

        const btcDecimal = await BTCContact.decimals()

        await idoDFYContract.setStage(0, { from: owner })

        const buyAmount = BigNumber(Math.pow(10, btcDecimal))
        await BTCContact.approve(idoDFYContractAddress, buyAmount, {from: ownerBTC})
        await idoDFYContract.buyIdo(BTCContractAddress, buyAmount, address0, {from: ownerBTC})

        const idoBalance = await DFYContract.balanceOf(ownerBTC, { from: ownerBTC })
        assert.equal(BigNumber(170000*Math.pow(10, 18)).isEqualTo(idoBalance), true, "Buy IDO with BTC success!")

    }).timeout(400000000);

    it("Buy IDO using BTC fail because exceed 500k", async () => {
        await idoDFYContract.updateExchangePair(BTCContractAddress, 170000, 1, {from: owner})
        await idoDFYContract.updateExchangePair(ETHContractAddress, 2000, 1, {from: owner})

        const btcDecimal = await BTCContact.decimals()

        await idoDFYContract.setStage(0, { from: owner })

        const buyAmount = BigNumber(2*Math.pow(10, btcDecimal))
        await BTCContact.approve(idoDFYContractAddress, buyAmount, {from: ownerBTC})

        try {
            await idoDFYContract.buyIdo(BTCContractAddress, buyAmount, address0, {from: ownerBTC})
        } catch (e) {
            console.log(e.message)
            assert.equal(e.message,
                "Returned error: VM Exception while processing transaction: revert Amount is exceeded! -- Reason given: Amount is exceeded!.",
                "Buy IDO with BTC fail becase: Amount is exceeded!!"
            )
        }

    }).timeout(400000000);

    it("Buy IDO using BTC success because not exceed 500k", async () => {
        await idoDFYContract.updateExchangePair(BTCContractAddress, 170000, 1, {from: owner})
        await idoDFYContract.updateExchangePair(ETHContractAddress, 2000, 1, {from: owner})

        const btcDecimal = await BTCContact.decimals()

        await idoDFYContract.setStage(0, { from: owner })

        const buyAmount = BigNumber(1.9*Math.pow(10, btcDecimal))
        await BTCContact.approve(idoDFYContractAddress, buyAmount, {from: ownerBTC})
        await idoDFYContract.buyIdo(BTCContractAddress, buyAmount, address0, {from: ownerBTC})

        const idoBalance = await DFYContract.balanceOf(ownerBTC, { from: ownerBTC })
        assert.equal(BigNumber(493000*Math.pow(10, 18)).isEqualTo(idoBalance), true, "Buy IDO with BTC success!")

    }).timeout(400000000);


})
