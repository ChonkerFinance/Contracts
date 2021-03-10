const hre = require('hardhat')

async function main () {
  const ethers = hre.ethers

  console.log('network:', await ethers.provider.getNetwork())

  const signer = (await ethers.getSigners())[0]
  console.log('signer:', await signer.getAddress())

  const TAIYAKI = await ethers.getContractFactory('TAIYAKI', {
    signer: (await ethers.getSigners())[0]
  })

  const taiyaki = await TAIYAKI.deploy()
  await taiyaki.deployed()

  console.log('TAIYAKI deployed to:', taiyaki.address)
  console.log(
    'deployed bytecode:',
    await ethers.provider.getCode(taiyaki.address)
  )

  console.log(
    'initial supply:',
    await taiyaki.totalSupply()
  )

  console.log('Deploying Swap contract')

  const FISHSwap = await ethers.getContractFactory('TaiyakiFISHSwap', {
    signer: (await ethers.getSigners())[0]
  })

  const swap = await FISHSwap.deploy(taiyaki.address, '0x802Ecd670aAf08311cc8BD887B3e1D9F419e0496')
  await swap.deployed()

  console.log('Swap  deployed to:', swap.address)
  console.log(
    'deployed bytecode:',
    await ethers.provider.getCode(swap.address)
  )

}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
