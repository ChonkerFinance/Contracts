const { l2ethers } = require('hardhat')
const { assert } = require('chai')
var Web3 = require('web3')

function tokens(n) {
  return Web3.utils.toWei(n, 'ether')
}

describe('TAIYAKI', function() {
  let account1, account2, account3;
  before(async function() {
    ;[account1, account2, account3] = await l2ethers.getSigners()
  })


  const name = 'TAIYAKI'
  const initialSupply = '500'
  let TAIYAKI

  before(async function() {
    const TAIYAKI_Contract = await l2ethers.getContractFactory('TAIYAKI')
    TAIYAKI = await TAIYAKI_Contract.connect(account1).deploy()
  
    await TAIYAKI.deployed();
  })
 
  

  describe('the basics', function()  {
    it('should have a name', async function()  {
      assert.equal(await TAIYAKI.name(), name, 'taiyaki not properly deployed')
    })

    it('should have a total supply equal to the initial supply', async function()  {

      assert.equal((await TAIYAKI.totalSupply()).toString(), tokens(initialSupply), 'taiyaki initial supply is not matched')
    })
  })
})