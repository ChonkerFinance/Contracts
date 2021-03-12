const hre = require('hardhat')

async function main () {
  const ethers = hre.ethers

  console.log('network:', await ethers.provider.getNetwork())

  const signer = (await ethers.getSigners())[0]
  console.log('signer:', await signer.getAddress())

  /**
   *  Taiyaki Token Deploy
   */
  // const TAIYAKI = await ethers.getContractFactory('TAIYAKI', {
  //   signer: (await ethers.getSigners())[0]
  // })

  // const taiyaki = await TAIYAKI.deploy()
  // await taiyaki.deployed()

  // console.log('TAIYAKI deployed to:', taiyaki.address)
  // console.log(
  //   'deployed bytecode:',
  //   await ethers.provider.getCode(taiyaki.address)
  // )

  // console.log(
  //   'initial supply:',
  //   await taiyaki.totalSupply()
  // )

  // /**
  //  *  Taiyaki - FISH swap Deploy
  //  *  Should add pairs  
  //  */

  // console.log('Deploying Swap contract')

  // const FISHSwap = await ethers.getContractFactory('TaiyakiFISHSwap', {
  //   signer: (await ethers.getSigners())[0]
  // })

  // const swap = await FISHSwap.deploy(taiyaki.address, '0x802Ecd670aAf08311cc8BD887B3e1D9F419e0496')
  // await swap.deployed()

  // console.log('Swap  deployed to:', swap.address)
  // console.log(
  //   'deployed bytecode:',
  //   await ethers.provider.getCode(swap.address)
  // )


  /**
   *  Taiyaki/ETH LP Pool Deploy
   *  use Taiyaki Address and LP token address as arg
   *  should set Reward per week : default : 10%
   *  should grant Minter role to this contract from Taiyaki Token contract 
   */
  console.log('Deploying Taiyaki/ETH LP contract')

  const TaiyakiETH = await ethers.getContractFactory('TaiyakiETHLP', {
    signer: (await ethers.getSigners())[0]
  })

  const lp = await TaiyakiETH.deploy('0x9908565B335873aDbd2E6B02371C1236ED0Ec72c', '0x212B2ee3C5F7cBaA5833456a600BED4538e49803')
  await lp.deployed()

  console.log('LP Pool  deployed to:', lp.address)
  console.log(
    'deployed bytecode:',
    await ethers.provider.getCode(lp.address)
  )

  await hre.run("verify:verify", {
    address: lp.address,
    constructorArguments: [
      '0x9908565B335873aDbd2E6B02371C1236ED0Ec72c',
      '0x212B2ee3C5F7cBaA5833456a600BED4538e49803'
    ],
  })

  console.log('LP Pool contract verified')

}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
