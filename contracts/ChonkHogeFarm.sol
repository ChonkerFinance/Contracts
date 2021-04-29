// ChonkHogeFarm contract - chonker.finance
pragma solidity 0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";



interface IChonkNFT {
  function mint(address to, uint256 id, uint256 amount) external;
}

contract ChonkHogeFarm is Ownable, ReentrancyGuard {
  using SafeMath for uint256;

  constructor(address _chonk_hoge) public {
    ChonkHogeAddress = _chonk_hoge;
  }

  address public ChonkHogeAddress;
  address public NFTAddress;

  function setNFTAddress(address _address) public onlyOwner {
    NFTAddress = _address;
  }

  mapping(address => uint256) private lpBalance;
  mapping(address => uint256) public lastUpdateTime;
  mapping(address => uint256) public points;

  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);

  modifier updateReward(address account) {
    if (account != address(0)) {
      points[account] = earned(account);
      lastUpdateTime[account] = block.timestamp;
    }
    _;
  }

  function balanceOf(address account) public view returns (uint256) {
    return lpBalance[account];
  }

  /*
  */
  function earned(address account) public view returns (uint256) {
    uint256 blockTime = block.timestamp;
    return points[account].add(blockTime.sub(lastUpdateTime[account]).mul(1e18).div(5760).mul(balanceOf(account).div(1e18)));
  }

  /*
  */
  function stake(uint256 amount) public updateReward(_msgSender()) nonReentrant {
    require(amount.add(balanceOf(_msgSender())) >= 1e18, "Cannot stake less than 1 Hoge/CHONK");
    require(amount.add(balanceOf(_msgSender())) <= 1e19, "Cannot stake more than 10 Hoge/CHONK");
    lpBalance[_msgSender()] = lpBalance[_msgSender()].add(amount);
    IERC20(ChonkHogeAddress).transferFrom(_msgSender(), address(this), amount);
    emit Staked(_msgSender(), amount);
  }

  function withdraw(uint256 amount) public updateReward(_msgSender()) nonReentrant {
    require(amount > 0, "Cannot withdraw 0");
    require(amount <= balanceOf(_msgSender()), "Cannot withdraw more than balance");
    IERC20(ChonkHogeAddress).transfer(_msgSender(), amount);
    lpBalance[_msgSender()] = lpBalance[_msgSender()].sub(amount);
    emit Withdrawn(_msgSender(), amount);
  }

  function exit() external {
    withdraw(balanceOf(_msgSender()));
  }

  mapping(uint256 => uint256) public redeemCost;
  
  function setRedeemCost(uint256 _id, uint256 _cost) public onlyOwner {
    redeemCost[_id] = _cost;
  }

    
  function redeem(uint256 _id) public updateReward(_msgSender()) nonReentrant {
    uint256 price = redeemCost[_id];
    require(price > 0, "Card not found");
    require(points[_msgSender()] >= price, "Not enough points to redeem");
    IChonkNFT(NFTAddress).mint(_msgSender(), _id, 1);
    points[_msgSender()] = points[_msgSender()].sub(price);
  }
}