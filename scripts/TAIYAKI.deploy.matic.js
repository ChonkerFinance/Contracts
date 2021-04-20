const hre = require('hardhat')

const sleep = (delay) => new Promise((resolve) => setTimeout(resolve, delay * 1000));

async function main () {
  const ethers = hre.ethers

  console.log('network:', await ethers.provider.getNetwork())

  const signer = (await ethers.getSigners())[0]
  console.log('signer:', await signer.getAddress())

  const deployFlags = {
    chonkToken: false,
    chonkNFTToken: false,
    taiyakiToken: false,
    taiyakiLPToken: false,
    taiyakiLPPool: false,
    taiyakiFishSwap: false,
    NFTManager: true,
    ChonkMachineManager: true,
  }

  let taiyakiTokenAddress = "0x1A5C71dDF3d71CBB0C0Bc312ff712a52cBe29cD2";
  let taiyakiLPTokenAddress = "";
  let NFTTokenAddress = "0xBdA6415502b0ddaB9EDA1D09F4f16286273Fdbb6";
  let NFTManagerAddress = "";
  /**
   *  Taiyaki LP Token Deploy
   */
   if(deployFlags.taiyakiLPToken) {
    console.log(' --------------------------------------- ')
    const TaiyakiLP = await ethers.getContractFactory('TAIYAKILP', {
      signer: (await ethers.getSigners())[0]
    })
  
    const taiyakiLP = await TaiyakiLP.deploy();
    await taiyakiLP.deployed()

    console.log('TAIYAKI-ETH LP token deployed to:', taiyakiLP.address)
    
    await sleep(60);
    await hre.run("verify:verify", {
      address: taiyakiLP.address,
      contract: "contracts/TAIYAKILP.sol:TAIYAKILP",
      constructorArguments: [],
    })

    taiyakiLPTokenAddress = taiyakiLP.address;
  
    console.log('Taiyaki-ETH LP Token contract verified')
  }

  /**
   *  ChonkNFT Token Deploy
   */
   if(deployFlags.chonkNFTToken) {
    console.log(' --------------------------------------- ')
    const ChonkNFT = await ethers.getContractFactory('ChonkNFT', {
      signer: (await ethers.getSigners())[0]
    })
  
    const nft = await ChonkNFT.deploy()
    await nft.deployed()
  
    console.log('Chonk NFT deployed to:', nft.address)
    await sleep(60);
    await hre.run("verify:verify", {
      address: nft.address,
      contract: "contracts/ChonkNFT.sol:ChonkNFT",
      constructorArguments: [],
    })

    NFTTokenAddress = nft.address;
  
    console.log('Chonk NFT Token contract verified')
  }

  /**
   *  Taiyaki Token Deploy
   */
  if(deployFlags.taiyakiToken) {
    console.log(' --------------------------------------- ')
    const TAIYAKI = await ethers.getContractFactory('TAIYAKI', {
      signer: (await ethers.getSigners())[0]
    })
  
    const taiyaki = await TAIYAKI.deploy()
    await taiyaki.deployed()
  
    console.log('TAIYAKI deployed to:', taiyaki.address)
    await sleep(60);
    await hre.run("verify:verify", {
      address: taiyaki.address,
      contract: "contracts/TAIYAKI.sol:TAIYAKI",
      constructorArguments: [],
    })

    taiyakiTokenAddress = taiyaki.address;
  
    console.log('Taiyaki Token contract verified')
  }

  // /**
  //  *  Taiyaki - FISH swap Deploy
  //  *  Should add pairs  
  //  */
  if(deployFlags.taiyakiFishSwap) {
    console.log(' --------------------------------------- ')
    console.log('Deploying Taiyaki - FISH swap contract')

    const FISHSwap = await ethers.getContractFactory('TaiyakiFISHSwap', {
      signer: (await ethers.getSigners())[0]
    })

    const swap = await FISHSwap.deploy(taiyakiTokenAddress, NFTTokenAddress)
    await swap.deployed()

    console.log('Swap  deployed to:', swap.address)
    await sleep(60);
    await hre.run("verify:verify", {
      address: swap.address,
      contract: "contracts/TaiyakiFISHSwap.sol:TaiyakiFISHSwap",
      constructorArguments: [
        taiyakiTokenAddress,
        NFTTokenAddress
      ],
    })
  }


  /**
   *  Taiyaki/ETH LP Pool Deploy
   *  use Taiyaki Address and LP token address as arg
   *  should set Reward per week : default : 10%
   *  should grant Minter role to this contract from Taiyaki Token contract 
   */
  if(deployFlags.taiyakiLPPool) {
    console.log(' --------------------------------------- ')
    console.log('Deploying Taiyaki/ETH LP contract')

    const TaiyakiETH = await ethers.getContractFactory('TaiyakiETHLP', {
      signer: (await ethers.getSigners())[0]
    })
  
    const lp = await TaiyakiETH.deploy(taiyakiLPTokenAddress, taiyakiTokenAddress)
    await lp.deployed()
  
    console.log('LP Pool  deployed to:', lp.address)
    await sleep(60);
    await hre.run("verify:verify", {
      address: lp.address,
      contract: "contracts/TaiyakiETHLP.sol:TaiyakiETHLP",
      constructorArguments: [
        taiyakiLPTokenAddress,
        taiyakiTokenAddress
      ],
    })
  
    console.log('LP Pool contract verified')
  }
  
  /**
   *  NFT Manager Contract
   *  should set ChonkNFT token contract address
   *  add default admin role and minter role to this contract from ChonkNFT
   *  add whitelist after deployed
   */
  if(deployFlags.NFTManager) {
    console.log(' --------------------------------------- ')
    console.log('Deploying NFTManager contract')

    const NFTManager = await ethers.getContractFactory('NFTManager', {
      signer: (await ethers.getSigners())[0]
    })
  
    const manager = await NFTManager.deploy(NFTTokenAddress)
    await manager.deployed()
  
    console.log('NFT Manager  deployed to:', manager.address)
    NFTManagerAddress = manager.address;
    await sleep(60);
    await hre.run("verify:verify", {
      address: manager.address,
      contract: "contracts/NFTManager.sol:NFTManager",
      constructorArguments: [
        NFTTokenAddress
      ],
    })
  
    console.log('NFT Manager contract verified')
  }


  /**
   *  ChonkMachineManager Contract
   *  should set Team, ChonkNFT, Taiyaki contract address
   *  
   *  
   */
   if(deployFlags.ChonkMachineManager) {
    console.log(' --------------------------------------- ')
    console.log('Deploying ChonkMachineManager contract')
    const teamAccount = "0xc2A79DdAF7e95C141C20aa1B10F3411540562FF7";
    const liquidityAccount = "0xc2A79DdAF7e95C141C20aa1B10F3411540562FF7";
    const wethAddress = "0xc778417e063141139fce010982780140aa0cd5ab";

    const ChonkMachineManager = await ethers.getContractFactory('ChonkMachineManager', {
      signer: (await ethers.getSigners())[0]
    })
  
    const manager = await ChonkMachineManager.deploy(teamAccount, liquidityAccount, NFTTokenAddress,NFTManagerAddress, taiyakiTokenAddress, wethAddress)
    await manager.deployed()
  
    console.log('ChonkMachineManager  deployed to:', manager.address)
    await sleep(60);
    await hre.run("verify:verify", {
      address: manager.address,
      contract: "contracts/ChonkMachineManager.sol:ChonkMachineManager",
      constructorArguments: [
        teamAccount, liquidityAccount, NFTTokenAddress,NFTManagerAddress, taiyakiTokenAddress, wethAddress
      ],
    })
  
    console.log('ChonkMachineManager contract verified')
  }

}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })
