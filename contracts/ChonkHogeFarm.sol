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
    unstakingFee = 1;
    rewardPerWeek = 10;

    feeAddress = 0x98B48C1B9654C0bda3cB7A1561b930E754A6641F;
  }

  address public ChonkHogeAddress;
  address public NFTAddress;
  address public feeAddress;

  /* Penelty Fee for unstaking (%) */
  uint256 public unstakingFee;
  uint256 public rewardPerWeek;

  function setNFTAddress(address _address) public onlyOwner {
    NFTAddress = _address;
  }

  function setFeeAddress(address _address) public onlyOwner {
    feeAddress = _address;
  }


  mapping(address => uint256) private lpBalance;
  mapping(address => uint256) public lastUpdateTime;
  mapping(address => uint256) public points;

  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);


  function setRewardPerWeek(uint256 _reward) external onlyOwner {
      rewardPerWeek = _reward;
  }

  function setUnstakingFee(uint256 _fee) external onlyOwner {
      require(_fee < 100, "Unstaking fee is too big");

      unstakingFee = _fee;
  }
  
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
    uint256 amount = blockTime.sub(lastUpdateTime[account]).mul(balanceOf(account)).mul(rewardPerWeek).div(60480000);
    return points[account].add(amount);
  }

  /*
  */
  function stake(uint256 amount) public updateReward(_msgSender()) nonReentrant {
    require(amount.add(balanceOf(_msgSender())) >= 1e17, "Cannot stake less than 0.1 CHONK/HOGE");
    require(amount.add(balanceOf(_msgSender())) <= 1e19, "Cannot stake more than 10 CHONK/HOGE");
    lpBalance[_msgSender()] = lpBalance[_msgSender()].add(amount);
    IERC20(ChonkHogeAddress).transferFrom(_msgSender(), address(this), amount);
    emit Staked(_msgSender(), amount);
  }

  function withdraw(uint256 amount) public updateReward(_msgSender()) nonReentrant {
    require(amount > 0, "Cannot withdraw 0");
    require(amount <= balanceOf(_msgSender()), "Cannot withdraw more than balance");

    uint256 fee = amount.mul(unstakingFee).div(100);
    require(IERC20(ChonkHogeAddress).transfer(feeAddress, fee), "Transfer unstaking fee failed");
    require(IERC20(ChonkHogeAddress).transfer(_msgSender(), amount.sub(fee)), "Transfer failed");
    lpBalance[_msgSender()] = lpBalance[_msgSender()].sub(amount);
   
    emit Withdrawn(_msgSender(), amount);
  }

  function exit() external {
    withdraw(balanceOf(_msgSender()));
  }

  mapping(uint256 => uint256) public redeemCost;

  event ListCard(uint256 id, uint256 cost);
  
  function setRedeemCost(uint256 _id, uint256 _cost) public onlyOwner {
    redeemCost[_id] = _cost;

    emit ListCard(_id, _cost);
  }

    
  function redeem(uint256 _id) public updateReward(_msgSender()) nonReentrant {
    uint256 price = redeemCost[_id];
    require(price > 0, "Card not found");
    require(points[_msgSender()] >= price, "Not enough points to redeem");
    IChonkNFT(NFTAddress).mint(_msgSender(), _id, 1);
    points[_msgSender()] = points[_msgSender()].sub(price);
  }
}