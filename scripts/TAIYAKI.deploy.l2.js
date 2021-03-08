const hre = require('hardhat')

async function main () {
  const ethers = hre.ethers
  const l2ethers = hre.l2ethers

  console.log('network:', await ethers.provider.getNetwork())

  const signer = (await ethers.getSigners())[0]
  console.log('signer:', await signer.getAddress())

  const TAIYAKI = await l2ethers.getContractFactory('TAIYAKI', {
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
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
