// TAIYAKI - FISH swap
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract TaiyakiFISHSwap is ReentrancyGuard, Pausable, Ownable {
    
    using SafeMath for uint256;

    /* TAIYAKI Token */
    address public taiyakiAddress;

    /* Pairs to swap token_address - price ex: price: 100 => 100 token = 1 taiyaki*/
    mapping(address => uint) public pairs;

    /* How many tokens we have successfully swapped */
    uint256 public totalSwapped;

    event TaiyakiAddressUpdated(address token);
    event PairUpdated(address token, uint price);
    event PairDeleted(address token);

    /* For following in the dashboard */
    event Swapped(address indexed owner, address token, uint256 amount);

    constructor(address _taiyaki) public {
        taiyakiAddress = _taiyaki;
        totalSwapped = 0;
    }

    function setTAIYAKIAddress(address _address) external onlyOwner {
        taiyakiAddress = _address;

        emit TaiyakiAddressUpdated(_address);
    }

    function updatePair(address _token, uint _price) external onlyOwner {
        require(_price > 0, "Price should be greater than zero");

        pairs[_token] = _price;
        emit PairUpdated(_token, _price);
    }

    function removePair(address _token) external onlyOwner {
        require(pairs[_token] != 0x0, "Not exist on pair");

        delete pairs[_token];
        emit PairDeleted(_token);
    }

    function swap(address tokenAddress, uint256 amount) external nonReentrant whenNotPaused {
        require(pairs[tokenAddress] != 0x0, "Not exist such pair");

        address swapper = address(this);
        IERC20 token = IERC20(tokenAddress);
        require(token.allowance(msg.sender, swapper) >= amount, "You need to first approve() enough tokens to swap for this contract");
        require(token.balanceOf(msg.sender) >= amount, "You do not have enough tokens to swap");

        uint256 taiyakiAmount = amount.mul(pairs[tokenAddress]);
        
        totalSwapped += taiyakiAmount;
        require(token.transferFrom(msg.sender, swapper, amount), "Could not retrieve tokens");
        ERC20PresetMinterPauser(taiyakiAddress).mint(msg.sender, taiyakiAmount);

        emit Swapped(msg.sender, tokenAddress, taiyakiAmount);
    }

}