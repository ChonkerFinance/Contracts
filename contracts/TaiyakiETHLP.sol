// TAIYAKI / ETH LP Pool
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract TaiyakiETHLP is ReentrancyGuard, Pausable, Ownable {
    
    using SafeMath for uint256;

    /* LP Token */
    address public LPAddress;
    /* TAIYAKI Token */
    address public taiyakiAddress;

    /* Taiyaki/ETH LP token balances*/
    mapping(address => uint256) public balances;
    /* Reward (Taiyaki) balances */
    mapping(address => uint256) public rewards;
    /* Last updated time */
    mapping(address => uint256) public lastUpdated;

    /* How many tokens we have successfully staked */
    uint256 public totalStaked;

    /* Staking Reward ratio ( every 1 week ) */
    uint256 public rewardPerWeek;

    /* Penelty Fee for unstaking (%) */
    uint public unstakingFee;
    /* Address for collecting fee */
    address public feeAddress;

    event TaiyakiAddressUpdated(address token);
    event RewardPerWeekUpdated(uint256 reward);

    event Staked(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event Redeem(address indexed account, uint256 amount);
    

    modifier updateReward(address account) {
        if (account != address(0)) {
            rewards[account] = earned(account);
            lastUpdated[account] = block.timestamp;
        }
        _;
    }

    constructor(address _lpAddress, address _taiyaki) public {
        LPAddress = _lpAddress;
        taiyakiAddress = _taiyaki;
        rewardPerWeek = 10;
        unstakingFee = 1;
        feeAddress = 0x98B48C1B9654C0bda3cB7A1561b930E754A6641F;
        totalStaked = 0;
    }

    function setTAIYAKIAddress(address _address) external onlyOwner {
        taiyakiAddress = _address;

        emit TaiyakiAddressUpdated(_address);
    }

    function setRewardPerWeek(uint256 _reward) external onlyOwner {
        rewardPerWeek = _reward;

        emit RewardPerWeekUpdated(_reward);
    }

    function setUnstakingFee(uint256 _fee) external onlyOwner {
        require(_fee < 100, "Unstaking fee is too big");

        unstakingFee = _fee;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function earned(address account) public view returns (uint256) {
        uint256 blockTime = block.timestamp;
        uint256 amount = blockTime.sub(lastUpdated[account]).mul(balanceOf(account)).mul(rewardPerWeek).div(60480000);
        return rewards[account].add(amount);
    }

    
    function stake(uint256 amount) public updateReward(_msgSender()) nonReentrant whenNotPaused {
        require(amount.add(balanceOf(_msgSender())) >= 1000000000000000000, "Cannot stake less than 1 LP");
        require(amount.add(balanceOf(_msgSender())) <= 10000000000000000000, "Cannot stake more than 10 LP");

        require(IERC20(LPAddress).transferFrom(_msgSender(), address(this), amount), "LP token was not successfully transferred to contract");
        balances[_msgSender()] = balances[_msgSender()].add(amount);
        totalStaked = totalStaked.add(amount);
        emit Staked(_msgSender(), amount);
    }

    function withdraw(uint256 amount) public updateReward(_msgSender()) nonReentrant {
        require(amount > 0, "Cannot withdraw 0");
        require(amount <= balanceOf(_msgSender()), "Cannot withdraw more than balance");

        uint256 fee = amount.mul(unstakingFee).div(100);
        require(IERC20(LPAddress).transfer(feeAddress, fee), "Transfer unstaking fee failed");
        require(IERC20(LPAddress).transfer(_msgSender(), amount.sub(fee)), "Transfer failed");
        balances[_msgSender()] = balances[_msgSender()].sub(amount);
        totalStaked = totalStaked.sub(amount);
        emit Withdrawn(_msgSender(), amount);
    }

    function exit() external {
        withdraw(balanceOf(_msgSender()));
        redeem(rewards[_msgSender()]);
    }

    function redeem(uint256 amount) public updateReward(_msgSender()) nonReentrant {
        require(amount > 0, "Cannot redeem 0");
        require(amount <= rewards[_msgSender()], "Not enough rewards to redeem");

        ERC20PresetMinterPauser(taiyakiAddress).mint(_msgSender(), amount);
        rewards[_msgSender()] = rewards[_msgSender()].sub(amount);
        emit Redeem(_msgSender(), amount);
    }
}