// ChonkClub contract - chonker.finance
pragma solidity 0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";

interface IChonkNFT {
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function mint(address to, uint256 id, uint256 amount) external;
}

interface ITaiyaki {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function mint(address to, uint256 amount) external;
}

contract ChonkClub is Ownable, ReentrancyGuard, ERC1155Holder {
    using SafeMath for uint256;

    uint256 constant public GYOZA_PER_MONTH = 100 * 1e18;
    uint256 constant public REWARD_CHAN_PER_MONTH = 5 * 1e17;
    uint256 constant public SECONDS_PER_MONTH = 30 * 24 * 3600;
    uint256 constant public PERCENTS_DIVIDER = 1000;

    address public ChonkAddress;
    address public TaiyakiAddress;
    address public NFTAddress;
    uint256 public chonkChainId;

    struct Tier {
        uint256 id;
        uint256 chonk;
        uint256 taiyakiPerMonth;
        uint256 cardId;
    }

    // Tier Id => Chonk Amount mapping
    mapping(uint256 => Tier) public tiers;
    uint256 currentTierId = 0;

    struct Holder {
        uint256 tier_id;
        uint256 taiyakiRewards;
        uint256 gyozaRewards;
        uint256 taiyakiUpdatedAt;
        uint256 gyozaUpdatedAt;
        uint256 gyozaRedeemAt;
        bool bChonkChainStaked;
        uint256 chonkChainUpdatedAt;

        uint256 regularStaked;
        uint256 rstakeUpdatedAt;
        uint256 rstakeRewards;  
        bool valid;
    }
    mapping(address => Holder) public holders;

    /**
        Regular Staking
     */
    uint256 public rstakeRewardPerWeek;   // Percentage - Max 1000



    event TierChanged(uint256 id, uint256 chonk, uint256 taiyakiPerMonth, uint256 cardId);
    event Staked(address indexed user, uint256 tier_id);
    event RegularStaked(address indexed user, uint256 amount);
    event ClaimedTaiyaki(address indexed user, uint256 amount);
    event RedeemedNFT(address indexed user, uint256 cardId);
    event RegularWithdrawn(address indexed user, uint256 amount);

    constructor(address _chonk, address _taiyaki, address _nft) public {
        ChonkAddress = _chonk;
        TaiyakiAddress = _taiyaki;
        NFTAddress = _nft;
        chonkChainId = 1;

        rstakeRewardPerWeek = 100; // 10%

        _changeTier(1, 50  * 1e18, 1e18, 0);
        _changeTier(2, 100 * 1e18, 2e18, 0);
        _changeTier(3, 150 * 1e18, 3e18, 0);
        _changeTier(4, 400 * 1e18, 4e18, 0);
    }

    function setNFTAddress(address _address) public onlyOwner {
        NFTAddress = _address;
    }

    function setChonkChanId(uint256 _card) public onlyOwner {
        chonkChainId = _card;
    }

    function setRewardPerWeek(uint256 _reward) external onlyOwner {
        rstakeRewardPerWeek = _reward;
    }

    function _changeTier(uint256 id, uint256 chonk, uint256 taiyakiPerMonth, uint256 card) internal returns(bool){
        tiers[id].id = id;
        tiers[id].chonk = chonk;
        tiers[id].taiyakiPerMonth = taiyakiPerMonth;
        tiers[id].cardId = card;

        emit TierChanged(id, chonk, taiyakiPerMonth, card);
        return true;
    }

    function changeTier(uint256 tier_id, uint256 chonk, uint256 taiyakiPerMonth, uint256 card) public onlyOwner {
        _changeTier(tier_id, chonk, taiyakiPerMonth, card);
    }

    function updateTierCards(uint256[] memory ids, uint256[] memory cards) public onlyOwner {
        require(cards.length == ids.length, "invalid length");

        for(uint i = 0; i < ids.length; i ++) {
            uint256 id = ids[i];
            tiers[id].cardId = cards[i];

            emit TierChanged(id, tiers[id].chonk, tiers[id].taiyakiPerMonth, cards[i]);
        }
    }

    modifier updateReward(address account) {
        if (account != address(0)) {
            holders[account].taiyakiRewards = earnedTaiyaki(account).add(earnedTaiyakiFromChonkChain(account));
            holders[account].gyozaRewards   = earnedGyoza(account);
            holders[account].rstakeRewards  = earnedRStake(account);
            holders[account].taiyakiUpdatedAt = block.timestamp;
            holders[account].gyozaUpdatedAt   = block.timestamp;
            holders[account].chonkChainUpdatedAt = block.timestamp;
            holders[account].rstakeUpdatedAt = block.timestamp;
        }
        _;
    }

    modifier updateRStakeReward(address account) {
        if (account != address(0)) {
            holders[account].rstakeRewards  = earnedRStake(account);
            holders[account].rstakeUpdatedAt = block.timestamp;
        }
        _;
    }

    function tierOf(address account) public view returns (uint256) {
        return holders[account].tier_id;
    }

    /*
        Calculate earned Taiyaki amount 
    */
    function earnedTaiyaki(address account) public view returns (uint256) {
        uint256 blockTime = block.timestamp;
        Holder memory holder = holders[account];
        
        if(holder.valid != true) return 0;

        Tier memory tier = tiers[holder.tier_id];
        uint256 rewards = blockTime.sub(holder.taiyakiUpdatedAt).mul(tier.taiyakiPerMonth).div(SECONDS_PER_MONTH);
        return holder.taiyakiRewards.add(rewards);
    }

    /*
        Calculate earned Taiyaki amount from staking ChonkChan
    */
    function earnedTaiyakiFromChonkChain(address account) public view returns (uint256) {
        uint256 blockTime = block.timestamp;
        Holder memory holder = holders[account];
        
        if(holder.valid != true) return 0;
        if(holder.bChonkChainStaked != true) return 0;

        uint256 rewards = blockTime.sub(holder.chonkChainUpdatedAt).mul(REWARD_CHAN_PER_MONTH).div(SECONDS_PER_MONTH);
        return rewards;
    }

    /*
        Calculate earned Gyoza amount 
    */
    function earnedGyoza(address account) public view returns (uint256) {
        uint256 blockTime = block.timestamp;
        Holder memory holder = holders[account];
        
        if(holder.valid != true) return 0;

        uint256 rewards = blockTime.sub(holder.gyozaUpdatedAt).mul(GYOZA_PER_MONTH).div(SECONDS_PER_MONTH);
        return holder.gyozaRewards.add(rewards);
    }


    /*
        Calculate earned RStake Reward 
    */
    function earnedRStake(address account) public view returns (uint256) {
        uint256 blockTime = block.timestamp;
        Holder memory holder = holders[account];

        uint256 rewards = (blockTime.sub(holder.rstakeUpdatedAt)).mul(holder.regularStaked).mul(rstakeRewardPerWeek).div(PERCENTS_DIVIDER.mul(604800));
        return holder.rstakeRewards.add(rewards);
    }

    /*
        Stake - require tier Id 
    */
    function stake(uint256 tier_id) public updateReward(_msgSender()) nonReentrant {
        require(tiers[tier_id].chonk > 0, "Invalid Tier id");
        require(holders[_msgSender()].valid == false, "already staked");
        require(IERC20(ChonkAddress).transferFrom(_msgSender(), address(this), tiers[tier_id].chonk), "failed to transfer Chonk");

        holders[_msgSender()].tier_id = tier_id;
        holders[_msgSender()].taiyakiRewards = 0;
        holders[_msgSender()].gyozaRewards = 0;
        holders[_msgSender()].gyozaRedeemAt = block.timestamp;
        holders[_msgSender()].valid = true;

        emit Staked(_msgSender(), tier_id);
    }

    function stakeChonkChan() public updateReward(_msgSender()) nonReentrant {
        require(holders[_msgSender()].valid, "Invalid Holder");
        require(holders[_msgSender()].bChonkChainStaked == false, "Chonk Chan already staked");
        IChonkNFT(NFTAddress).safeTransferFrom(_msgSender(), address(this), chonkChainId, 1, "Stake");

        holders[_msgSender()].bChonkChainStaked = true;
    }

    function claimTaiyaki(uint256 amount) public updateReward(_msgSender()) nonReentrant {
        require(amount > 0, "Invalid Amount");
        Holder storage holder = holders[_msgSender()];
        require(holder.valid, "Invalid holder");
        require(amount <= holder.taiyakiRewards, "Cannot withdraw more than balance");
        ITaiyaki(TaiyakiAddress).mint(_msgSender(), amount);
        holder.taiyakiRewards = holder.taiyakiRewards.sub(amount);
        emit ClaimedTaiyaki(_msgSender(), amount);
    }

    function redeemMonthlyNFT() public updateReward(_msgSender()) nonReentrant {
        Holder storage holder = holders[_msgSender()];
        require(holder.valid, "Invalid holder");
        require(GYOZA_PER_MONTH <= holder.gyozaRewards, "Cannot withdraw more than balance");
        require(uint256(block.timestamp).sub(holder.gyozaRedeemAt) >= SECONDS_PER_MONTH, "Can redeem NFT at once every month");

        Tier memory tier = tiers[holder.tier_id];
        require(tier.cardId > 0 , "Not inited card to Tier yet");

        IChonkNFT(NFTAddress).mint(_msgSender(), tier.cardId, 1);
        holder.gyozaRewards = holder.gyozaRewards.sub(GYOZA_PER_MONTH);
        holder.gyozaRedeemAt = block.timestamp;
        emit RedeemedNFT(_msgSender(), tier.cardId);
    }

    function unstakeChonkChan() public updateReward(_msgSender()) nonReentrant {
        Holder storage holder = holders[_msgSender()];
        require(holder.bChonkChainStaked, "not staked");
        IChonkNFT(NFTAddress).safeTransferFrom(address(this), _msgSender(), chonkChainId, 1, "UnStake");

        holder.bChonkChainStaked = false;
    }

    function exit() external {
        Holder storage holder = holders[_msgSender()];
        require(holder.valid, "Invalid holder");

        Tier memory tier = tiers[holder.tier_id];

        claimTaiyaki(holder.taiyakiRewards);
        IERC20(ChonkAddress).transfer(_msgSender(), tier.chonk);
        if(holder.bChonkChainStaked) {
            IChonkNFT(NFTAddress).safeTransferFrom(address(this), _msgSender(), chonkChainId, 1, "UnStake");
        }
        holder.tier_id = 0;
        holder.valid = false;
        holder.bChonkChainStaked = false;
    }



    /*
        Stake Regular- require amount
    */
    function rstake(uint256 amount) public updateRStakeReward(_msgSender()) nonReentrant {
        require(amount.add(holders[_msgSender()].rstakeRewards) >= 1e18, "Cannot stake less than 1 CHONK");
        require(amount.add(holders[_msgSender()].rstakeRewards) < 50e18, "Cannot stake more than 50 CHONK");
        
        require(IERC20(ChonkAddress).transferFrom(_msgSender(), address(this), amount), "failed to transfer Chonk");
        holders[_msgSender()].regularStaked = holders[_msgSender()].regularStaked.add(amount);
        emit RegularStaked(_msgSender(), amount);
    }

    function withdrawRStake(uint256 amount) public updateRStakeReward(_msgSender()) nonReentrant {
        require(amount > 0, "Cannot withdraw 0");
        Holder storage holder = holders[_msgSender()];
        require(amount <= holder.regularStaked, "Cannot withdraw more than balance");

        require(IERC20(ChonkAddress).transfer(_msgSender(), amount), "Transfer failed");
        holder.regularStaked = holder.regularStaked.sub(amount);
        emit RegularWithdrawn(_msgSender(), amount);
    }

    function claimTaiyakiFromRStake(uint256 amount) public updateRStakeReward(_msgSender()) nonReentrant {
        require(amount > 0, "Invalid Amount");
        Holder storage holder = holders[_msgSender()];
        require(amount <= holder.rstakeRewards, "Cannot withdraw more than balance");
        ITaiyaki(TaiyakiAddress).mint(_msgSender(), amount);
        holder.rstakeRewards = holder.rstakeRewards.sub(amount);
        emit ClaimedTaiyaki(_msgSender(), amount);
    }

    function exitRStake() external {
        Holder storage holder = holders[_msgSender()];
    
        claimTaiyakiFromRStake(holder.rstakeRewards);
        IERC20(ChonkAddress).transfer(_msgSender(), holder.regularStaked);

        holder.regularStaked = 0;
    }
}