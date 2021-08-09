// LP Pool  - Chonker.Finance
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract LPStaking is ReentrancyGuard, Pausable, Ownable {
    
    using SafeMath for uint256;

    uint256 constant public PERCENTS_DIVIDER = 1000;

    /* LP Token */
    address public LPAddress;
    /* Reward Token */
    address public rewardTokenAddress;

    /* Staked LP token balances*/
    mapping(address => uint256) public balances;
    /* Reward balances */
    mapping(address => uint256) public rewards;
    /* Last updated time */
    mapping(address => uint256) public lastUpdated;

    /* How many tokens we have successfully staked */
    uint256 public totalStaked;

    /* Staking Reward ratio ( every 1 week ) */
    uint256 public rewardPerWeek;

    uint256 public minStakingAmount;
    uint256 public maxStakingAmount;

    /* Penelty Fee for unstaking (%) */
    uint public unstakingFee;
    /* Address for collecting fee */
    address public feeAddress;

    event RewardAddressUpdated(address token);
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

    constructor(address _lpAddress, 
        address _reward, 
        uint256 _rewardPerBlock, 
        uint256 _unstakingFee,
        uint256 _minStaking,
        uint256 _maxStaking
        ) {
        LPAddress = _lpAddress;
        rewardTokenAddress = _reward;
        rewardPerWeek = _rewardPerBlock;
        unstakingFee = _unstakingFee;
        minStakingAmount = _minStaking;
        maxStakingAmount = _maxStaking;
        feeAddress = 0x98B48C1B9654C0bda3cB7A1561b930E754A6641F;
    }

    function setRewardTokenAddress(address _address) external onlyOwner {
        require(_address != address(0x0), "invalid address");
        rewardTokenAddress = _address;

        emit RewardAddressUpdated(_address);
    }

    function setRewardPerWeek(uint256 _reward) external onlyOwner {
        rewardPerWeek = _reward;

        emit RewardPerWeekUpdated(_reward);
    }

    function setUnstakingFee(uint256 _fee) external onlyOwner {
        require(_fee < PERCENTS_DIVIDER, "Unstaking fee is too big");

        unstakingFee = _fee;
    }
    
    function setMinMaxAmount(uint256 _min, uint256 _max) external onlyOwner {
        require(_max > 0 && _max >= _min, "Invalid Max amount");

        minStakingAmount = _min;
        maxStakingAmount = _max;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function earned(address account) public view returns (uint256) {
        uint256 blockTime = block.timestamp;
        uint256 amount = blockTime.sub(lastUpdated[account]).mul(balanceOf(account)).mul(rewardPerWeek).div(604800).div(PERCENTS_DIVIDER);
        return rewards[account].add(amount);
    }

    
    function stake(uint256 amount) public updateReward(_msgSender()) nonReentrant whenNotPaused {
        require(amount.add(balanceOf(_msgSender())) >= minStakingAmount , "Cannot stake less than Min Limitation");
        require(amount.add(balanceOf(_msgSender())) <= maxStakingAmount, "Cannot stake more than Max Limitation");

        require(IERC20(LPAddress).transferFrom(_msgSender(), address(this), amount), "LP token was not successfully transferred to contract");
        balances[_msgSender()] = balances[_msgSender()].add(amount);
        totalStaked = totalStaked.add(amount);
        emit Staked(_msgSender(), amount);
    }

    function withdraw(uint256 amount) public updateReward(_msgSender()) nonReentrant {
        require(amount > 0, "Cannot withdraw 0");
        require(amount <= balanceOf(_msgSender()), "Cannot withdraw more than balance");

        uint256 fee = amount.mul(unstakingFee).div(100);
        if(fee > 0) {
            require(IERC20(LPAddress).transfer(feeAddress, fee), "Transfer unstaking fee failed");
        }

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

        ERC20PresetMinterPauser(rewardTokenAddress).mint(_msgSender(), amount);
        rewards[_msgSender()] = rewards[_msgSender()].sub(amount);
        emit Redeem(_msgSender(), amount);
    }
}