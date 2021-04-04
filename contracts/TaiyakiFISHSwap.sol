// TAIYAKI - FISH swap Chonker.Finance
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface IChonkNFT {
  function safeTransferFrom(address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data) external;
  function balanceOf(address account, uint256 id) external view returns (uint256);
}

contract TaiyakiFISHSwap is ReentrancyGuard, Pausable, Ownable {
    
    using SafeMath for uint256;

    /* TAIYAKI Token */
    address public taiyakiAddress;
    address public NFTAddress;

    /* Pairs to swap NFT _id => price */
    mapping(uint256 => uint256) public pairs;

    /* How many tokens we have successfully swapped */
    uint256 public totalSwapped;

    event TaiyakiAddressUpdated(address token);
    event NFTAddressUpdated(address nft);
    event PairAdded(uint256 id, uint256 price);
    
    /* For following in the dashboard */
    event Swapped(address indexed owner, uint256 id, uint256 amount);

    constructor(address _taiyaki, address _nft) public {
        taiyakiAddress = _taiyaki;
        NFTAddress = _nft;
        totalSwapped = 0;
    }

    function setTAIYAKIAddress(address _address) external onlyOwner {
        taiyakiAddress = _address;

        emit TaiyakiAddressUpdated(_address);
    }

    function setNFTAddress(address _address) external onlyOwner {
        NFTAddress = _address;

        emit NFTAddressUpdated(_address);
    }

    function addPair(uint256 _id, uint256 _price) public onlyOwner {
        pairs[_id] = _price;
        emit PairAdded(_id, _price);
    }

    
    function swap(uint256 _id, uint256 _amount) external nonReentrant whenNotPaused {
        require(pairs[_id] != 0x0, "Can not find Pair");

        IChonkNFT nft = IChonkNFT(NFTAddress);
        require(nft.balanceOf(msg.sender, _id) >= _amount, "You do not have enough tokens to swap");

        uint256 taiyakiAmount = _amount.mul(1e18).div(pairs[_id]);
        
        totalSwapped += taiyakiAmount;
        nft.safeTransferFrom(msg.sender, 0x000000000000000000000000000000000000dEaD, _id, _amount, "");

        ERC20PresetMinterPauser(taiyakiAddress).mint(msg.sender, taiyakiAmount);

        emit Swapped(msg.sender, _id, taiyakiAmount);
    }
}