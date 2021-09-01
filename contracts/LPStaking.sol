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

    struct PoolInfo {
        /* LP Token */
        address LPAddress;
        /* Reward Token */
        address rewardTokenAddress;

        /* Staking Reward ratio ( every 1 week ) */
        uint256 rewardPerWeek;

        uint256 minStakingAmount;
        uint256 maxStakingAmount;

        /* Penelty Fee for unstaking (%) */
        uint unstakingFee;
            
        /* How many tokens we have successfully staked */
        uint256 totalStaked;
    }
    
    struct UserInfo {
        uint256 balance;
        uint256 rewards;
        uint256 lastUpdated;
    }

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    mapping(address => bool) public poolExistence;

    /* Address for collecting fee */
    address public feeAddress;

    event RewardAddressUpdated(uint256 pid, address token);
    event RewardPerWeekUpdated(uint256 pid, uint256 reward);

    event Staked(uint256 pid, address indexed account, uint256 amount);
    event Withdrawn(uint256 pid, address indexed account, uint256 amount);
    event Redeem(uint256 pid, address indexed account, uint256 amount);
    

    modifier updateReward(uint256 pid, address account) {
        if (account != address(0)) {
            UserInfo storage uInfo = userInfo[pid][account];
            uInfo.rewards = earned(pid, account);
            uInfo.lastUpdated = block.timestamp;
        }
        _;
    }

    modifier nonDuplicated(address _lpToken) {
        require(poolExistence[_lpToken] == false, "nonDuplicated: duplicated");
        _;
    }


    constructor(address _feeAddress) {
        feeAddress = _feeAddress;
    }

    function addPool(address _lpAddress, 
        address _reward, 
        uint256 _rewardPerWeek, 
        uint256 _unstakingFee,
        uint256 _minStaking,
        uint256 _maxStaking
        ) public onlyOwner nonDuplicated(_lpAddress) {
        
        poolExistence[_lpAddress] = true;

        poolInfo.push(PoolInfo({
            LPAddress: _lpAddress,
            rewardTokenAddress: _reward,
            rewardPerWeek: _rewardPerWeek,
            minStakingAmount: _minStaking,
            maxStakingAmount: _maxStaking,
            unstakingFee: _unstakingFee,
            totalStaked: 0
        }));
    }

    function setRewardTokenAddress(uint256 _pid, address _address) external onlyOwner {
        require(_address != address(0x0), "invalid address");
        poolInfo[_pid].rewardTokenAddress = _address;

        emit RewardAddressUpdated(_pid, _address);
    }

    function setRewardPerWeek(uint256 _pid, uint256 _reward) external onlyOwner {
        poolInfo[_pid].rewardPerWeek = _reward;

        emit RewardPerWeekUpdated(_pid, _reward);
    }

    function setUnstakingFee(uint256 _pid, uint256 _fee) external onlyOwner {
        require(_fee < PERCENTS_DIVIDER, "Unstaking fee is too big");

        poolInfo[_pid].unstakingFee = _fee;
    }
    
    function setMinMaxAmount(uint256 _pid, uint256 _min, uint256 _max) external onlyOwner {
        require(_max > 0 && _max >= _min, "Invalid Max amount");

        poolInfo[_pid].minStakingAmount = _min;
        poolInfo[_pid].maxStakingAmount = _max;
    }

    function balanceOf(uint256 _pid, address account) public view returns (uint256) {
        return userInfo[_pid][account].balance;
    }

    function earned(uint256 _pid, address account) public view returns (uint256) {
        uint256 blockTime = block.timestamp;
        UserInfo memory uInfo = userInfo[_pid][account];
        PoolInfo memory pInfo = poolInfo[_pid];

        uint256 amount = blockTime.sub(uInfo.lastUpdated).mul(balanceOf(_pid, account)).mul(pInfo.rewardPerWeek).div(604800).div(PERCENTS_DIVIDER);
        return uInfo.rewards.add(amount);
    }

    
    function stake(uint256 _pid, uint256 amount) public updateReward(_pid, _msgSender()) nonReentrant whenNotPaused {
        UserInfo storage uInfo = userInfo[_pid][_msgSender()];
        PoolInfo storage pInfo = poolInfo[_pid];

        require(amount.add(uInfo.balance) >= pInfo.minStakingAmount , "Cannot stake less than Min Limitation");
        require(amount.add(uInfo.balance) <= pInfo.maxStakingAmount, "Cannot stake more than Max Limitation");

        require(IERC20(pInfo.LPAddress).transferFrom(_msgSender(), address(this), amount), "LP token was not successfully transferred to contract");
        uInfo.balance = uInfo.balance.add(amount);
        pInfo.totalStaked = pInfo.totalStaked.add(amount);
        emit Staked(_pid, _msgSender(), amount);
    }

    function withdraw(uint256 _pid, uint256 amount) public updateReward(_pid, _msgSender()) nonReentrant {
        require(amount > 0, "Cannot withdraw 0");
        require(amount <= balanceOf(_pid, _msgSender()), "Cannot withdraw more than balance");

        UserInfo storage uInfo = userInfo[_pid][_msgSender()];
        PoolInfo storage pInfo = poolInfo[_pid];
        
        uint256 fee = amount.mul(pInfo.unstakingFee).div(PERCENTS_DIVIDER);
        if(fee > 0) {
            require(IERC20(pInfo.LPAddress).transfer(feeAddress, fee), "Transfer unstaking fee failed");
        }

        require(IERC20(pInfo.LPAddress).transfer(_msgSender(), amount.sub(fee)), "Transfer failed");
        uInfo.balance = uInfo.balance.sub(amount);
        pInfo.totalStaked = pInfo.totalStaked.sub(amount);
        emit Withdrawn(_pid, _msgSender(), amount);
    }

    function exit(uint256 _pid) external {
        UserInfo memory uInfo = userInfo[_pid][_msgSender()];
        withdraw(_pid, uInfo.balance);
        redeem(_pid, uInfo.rewards);
    }

    function redeem(uint256 _pid, uint256 amount) public updateReward(_pid, _msgSender()) nonReentrant {
        require(amount > 0, "Cannot redeem 0");

        UserInfo storage uInfo = userInfo[_pid][_msgSender()];
        PoolInfo storage pInfo = poolInfo[_pid];

        require(amount <= uInfo.rewards, "Not enough rewards to redeem");

        ERC20PresetMinterPauser(pInfo.rewardTokenAddress).mint(_msgSender(), amount);
        uInfo.rewards = uInfo.rewards.sub(amount);
        emit Redeem(_pid, _msgSender(), amount);
    }
}