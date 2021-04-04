// NFT Token Manager - Chonker.finance
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface IChonkNFT {
  function addCard(uint256 maxSupply) external returns (uint256);
  function mint(address to, uint256 id, uint256 amount) external;
}

contract NFTManager is ReentrancyGuard, Ownable {
    
    using SafeMath for uint256;

    address public NFTAddress;


    mapping(uint256 => uint256) public tokenQuantityWithId;
    mapping(uint256 => uint256) public tokenMaxQuantityWithId;
   
    mapping(uint256 => address) public creators;
    mapping(uint256 => mapping(address => bool)) public minters;
    uint256 [] public tokenIds;
    uint256 public tokenIdAmount;

    bool public onlyWhitelist = true;
    mapping(address => bool) public whitelist;

     /* For following in the dashboard */
    event Create(uint256 tokenId, uint256 max_supply, bytes name);
    event Mint(uint256 tokenId, address to, uint256 quantity,  uint256 tokenMaxQuantity, uint256 tokenCurrentQuantity);

    constructor(address _nft) public {
        NFTAddress = _nft;
    }

    function setNFTAddress(address _address) external onlyOwner {
        NFTAddress = _address;
    }

    function create(uint256 _max_supply, bytes calldata name) external nonReentrant returns (uint256) {
        if (onlyWhitelist) {
            require(whitelist[msg.sender], "Open to only whitelist.");
        }

        uint256 tokenId = IChonkNFT(NFTAddress).addCard(_max_supply);
        require(tokenId != 0x0, "Failed to add card");

        tokenQuantityWithId[tokenId] = 0;
        tokenMaxQuantityWithId[tokenId] = _max_supply;

        tokenIds.push(tokenId);
        tokenIdAmount = tokenIdAmount.add(1);
        creators[tokenId] = msg.sender;

        emit Create(tokenId, _max_supply, name);
        return tokenId;
    }

    function mint(address to, uint256 tokenId, uint256 quantity) external {
        require(creators[tokenId] == msg.sender || minters[tokenId][msg.sender], "You are not the creator or minter of this NFT.");
        require(_isTokenIdExist(tokenId), "Token is is not exist.");
        require(tokenMaxQuantityWithId[tokenId] >= tokenQuantityWithId[tokenId] + quantity, "NFT quantity is greater than max supply.");
     
        IChonkNFT(NFTAddress).mint(to, tokenId, quantity);
        tokenQuantityWithId[tokenId] = tokenQuantityWithId[tokenId].add(quantity);
        emit Mint(tokenId, to, quantity, tokenMaxQuantityWithId[tokenId], tokenQuantityWithId[tokenId]);
    }

    function _isTokenIdExist(uint256 tokenId) private view returns(bool) {
        return creators[tokenId] != address(0);
    }

    function addToWhitelist(address account) public onlyOwner {
        whitelist[account] = true;
    }

    function removeFromWhitelist(address account) public onlyOwner {
        whitelist[account] = false;
    }

    function openToEveryone() public onlyOwner {
        onlyWhitelist = false;
    }

    function openOnlyToWhitelist() public onlyOwner {
        onlyWhitelist = true;
    }

    function addMinter(uint256 id, address account) public onlyCreator(id) {
        minters[id][account] = true;
    }

    function removeMinter(uint256 id, address account) public onlyCreator(id) {
        minters[id][account] = false;
    }

    function transferCreator(uint256 id, address account) public onlyCreator(id) {
        creators[id] = account;
    }

    modifier onlyCreator(uint256 id) {
        require(msg.sender == creators[id], "only for creator of this NFT.");
        _;
    }
}