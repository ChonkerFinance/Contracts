// Chonker Gachapon Machine contract 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

interface IChonkNFT {
  function safeTransferFrom(address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data) external;
  function balanceOf(address account, uint256 id) external view returns (uint256);
  function mint(address to, uint256 id, uint256 amount) external;
}

interface IChonkMachineManager {
    function isStaff(address account) external view returns(bool);
    function getPaymentAccounts() external view returns(address, address);
}

contract ChonkMachine is ERC1155Holder {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @dev Game round
     */
    struct Round {
        uint256 id; // request id.
        address player; // address of player.
        RoundStatus status; // status of the round.
        uint256 times; // how many times of this round;
        uint256 totalTimes; // total time of an account.
        uint256[20] cards; // Prize card of this round.
    }

    enum RoundStatus { Pending, Finished } // status of this round
    mapping(address => Round) public gameRounds;
    uint256 public currentRoundIdCount; //until now, the total round of this Gamemachine.
    uint256 public totalRoundCount;

    uint256 public machineId;
    string public machineTitle;
    string public machineDescription;
    string public machineUri;
    // [Team?, ETH-Spin?, TaiyakiLP %, Chonk Buyback %, Chonk LP %, Team Funds %, Artist Funds%, Burn %]
    uint256 public machineOptionIdx;
    uint256[8] public machineOption;
    bool public maintaining = true;
    bool public banned = false;

    // This is a set which contains cardID
    EnumerableSet.UintSet private _cardsSet;
    // This mapping contains cardId => amount
    mapping(uint256 => uint256) public amountWithId;
    // Prize pool with a random number to cardId
    mapping(uint256 => uint256) private _prizePool;
    // The amount of cards in this machine.
    uint256 public cardAmount;

    uint256 private _salt;
    uint256 public shuffleCount = 20;

     //[TaiyakiLP %, Chonk Buyback %, Chonk LP %, Team Funds %, Artist Funds%, Burn %] 
    uint256[6] public totalAmounts;
    
    address public burnAccount;
    address public artistAccount;
    address public teamAccount;
    address public liquidityAccount;

    EnumerableSet.AddressSet private _staffAccountSet;
    
    address public manager;
    address public owner;
    address public administrator;

    // Currency of the game machine, like Taiyaki, WETH
    IERC20 public taiyakiToken;
    IERC20 public wethToken;
    IChonkNFT public nftToken;

    uint256 public playOncePrice;


    event AddCard(uint256 cardId, uint256 amount, uint256 cardAmount);
    event RemoveCard(uint256 card, uint256 removeAmount, uint256 cardAmount);
    event RunMachine(address account, uint256 times, uint256 playFee);

    event MachineLocked(bool locked);

    constructor(uint256 _machineId, //machine id
                string memory _machineTitle, // machine title.
                string memory _machineDescription, // machine description
                uint256 _price,
                address _owner,
                address _administrator,
                address _teamAccount,
                address _liquidityAccount
                ) {
        machineId = _machineId;
        playOncePrice = _price;
    
        _setupMachineTitle(_machineTitle);
        _setupMachineDescription(_machineDescription);

        burnAccount = 0x000000000000000000000000000000000000dEaD;
        administrator = _administrator;
        owner = _owner;
        artistAccount = _owner;
        manager = msg.sender;
        teamAccount = _teamAccount;
        liquidityAccount = _liquidityAccount;

        _staffAccountSet.add(administrator);
    }

    //setup title
    function _setupMachineTitle(string memory _title) private {
        machineTitle = _title;
    }

    function _setupMachineDescription(string memory _description) private {
        machineDescription = _description;
    }

    function _checkMachineOption(uint256[8] memory option) pure private {
        //[Team?, ETH-Spin?, TaiyakiLP %, Chonk Buyback %, Chonk LP %, Team Funds %, Artist Funds%, Burn %] 
        require(option[2].add(option[3]).add(option[4]).add(option[5]).add(option[6]).add(option[7]) <= 100, "Invalid Machine Option");
    }

    //setup Machine Option
    function setupMachineOption(uint256 _option_idx, uint256[8] calldata option) external onlyManager {
        _checkMachineOption(option);
        machineOptionIdx = _option_idx;
        machineOption = option;
    }

    function setupTokenAddresses(address _nft, address _taiyaki, address _weth) external onlyManager {
        nftToken = IChonkNFT(_nft);
        taiyakiToken = IERC20(_taiyaki);
        wethToken = IERC20(_weth);
        _salt = uint256(keccak256(abi.encodePacked(_nft, _taiyaki, block.timestamp))).mod(10000);
    }

    /**
     * @dev Add cards which have been minted, and your owned cards
     * @param cardId. Card id you want to add.
     * @param amount. How many cards you want to add.
     */
    function addCard(uint256 cardId, uint256 amount, bool _mint) public onlyOwner unbanned {
        if(_mint) {
            nftToken.mint(address(this), cardId, amount);
        }else {
            require(nftToken.balanceOf(msg.sender, cardId) >= amount, "You don't have enough Cards");
            nftToken.safeTransferFrom(msg.sender, address(this), cardId, amount, "Add Card");
        }

        _cardsSet.add(cardId);
        amountWithId[cardId] = amountWithId[cardId].add(amount);
        for (uint256 i = 0; i < amount; i ++) {
            _prizePool[cardAmount + i] = cardId;
        }
        cardAmount = cardAmount.add(amount);
        emit AddCard(cardId, amount, cardAmount);
    }

    function runMachine(uint256 userProvidedSeed, uint256 times) public onlyHuman unbanned {
        require(!maintaining, "This machine is under maintenance");
        require(!banned, "This machine is banned.");
        require(cardAmount > 0, "There is no card in this machine anymore.");
        require(times > 0, "Times can not be 0");
        require(times <= 20, "Over times.");
        require(times <= cardAmount, "You play too many times.");
        _createARound(times);
        // get random seed with userProvidedSeed and address of sender.
        uint256 seed = uint256(keccak256(abi.encode(userProvidedSeed, msg.sender)));

        if (cardAmount > shuffleCount) {
            _shufflePrizePool(seed);
        }

        for (uint256 i = 0; i < times; i ++) {
            // get randomResult with seed and salt, then mod cardAmount.
            uint256 randomResult = _getRandomNumebr(seed, _salt, cardAmount);
            // update random salt.
            _salt = ((randomResult + cardAmount + _salt) * (i + 1) * block.timestamp).mod(cardAmount) + 1;
            // transfer the cards.
            uint256 result = (randomResult * _salt).mod(cardAmount);
            _updateRound(result, i);
        }

        totalRoundCount = totalRoundCount.add(times);
        uint256 playFee = playOncePrice.mul(times);
        _transferAndBurnToken(playFee);
        _distributePrize();

        emit RunMachine(msg.sender, times, playFee);
    }

    /**
     * @param amount how much token will be needed and will be burned.
     */
    function _transferAndBurnToken(uint256 amount) private {
        uint256 totalPaid = 0;
        address[6] memory accounts = [liquidityAccount, liquidityAccount, liquidityAccount, teamAccount, artistAccount, burnAccount];
        IERC20 payToken = machineOption[1] == 1 ? wethToken : taiyakiToken;
        for(uint i = 0 ; i < 6; i++) {
            if(machineOption[i+2] != 0 && accounts[i] != address(0x0)) {
                uint256 rateAmount = amount.mul(machineOption[i+2]).div(100);
                if(rateAmount > 0) {
                    payToken.transferFrom(msg.sender, accounts[i], rateAmount);
                    totalAmounts[i] = totalAmounts[i].add(rateAmount);
                    totalPaid = totalPaid.add(rateAmount);
                }
            }
        }
        uint256 remainingAmount = amount.sub(totalPaid);
        if(remainingAmount > 0) {
            payToken.transferFrom(msg.sender, teamAccount, remainingAmount);
        }
    }


    function _distributePrize() private {
        for (uint i = 0; i < gameRounds[msg.sender].times; i ++) {
            uint256 cardId = gameRounds[msg.sender].cards[i];
            require(amountWithId[cardId] > 0, "No enough cards of this kind in the Mchine.");

            nftToken.safeTransferFrom(address(this), msg.sender, cardId, 1, 'Your prize from Chonker Gachapon');

            amountWithId[cardId] = amountWithId[cardId].sub(1);
            if (amountWithId[cardId] == 0) {
                _removeCardId(cardId);
            }
        }
        gameRounds[msg.sender].status = RoundStatus.Finished;
    }

    function _updateRound(uint256 randomResult, uint256 rand) private {
        uint256 cardId = _prizePool[randomResult];
        _prizePool[randomResult] = _prizePool[cardAmount - 1];
        cardAmount = cardAmount.sub(1);
        gameRounds[msg.sender].cards[rand] = cardId;
    }

    function _getRandomNumebr(uint256 seed, uint256 salt, uint256 mod) view private returns(uint256) {
        return uint256(keccak256(abi.encode(block.timestamp, block.difficulty, block.coinbase, blockhash(block.number + 1), seed, salt, block.number))).mod(mod);
    }

    function _createARound(uint256 times) private {
        gameRounds[msg.sender].id = currentRoundIdCount + 1;
        gameRounds[msg.sender].player = msg.sender;
        gameRounds[msg.sender].status = RoundStatus.Pending;
        gameRounds[msg.sender].times = times;
        gameRounds[msg.sender].totalTimes = gameRounds[msg.sender].totalTimes.add(times);
        currentRoundIdCount = currentRoundIdCount.add(1);
    }

    // shuffle the prize pool again.
    function _shufflePrizePool(uint256 seed) private {
        for (uint256 i = 0; i < shuffleCount; i++) {
            uint256 randomResult = _getRandomNumebr(seed, _salt, cardAmount);
            _salt = ((randomResult + cardAmount + _salt) * (i + 1) * block.timestamp).mod(cardAmount);
            _swapPrize(i, _salt);
        }
    }

    function _swapPrize(uint256 a, uint256 b) private {
        uint256 temp = _prizePool[a];
        _prizePool[a] = _prizePool[b];
        _prizePool[b] = temp;
    }

    function _removeCardId(uint256 _cardId) private {
        _cardsSet.remove(_cardId);
    }

    function cardIdCount() view public returns(uint256) {
        return _cardsSet.length();
    }

    function cardIdWithIndex(uint256 index) view public returns(uint256) {
        return _cardsSet.at(index);
    }

    function changePlayOncePrice(uint256 newPrice) public onlyOwner {
        playOncePrice = newPrice;
    }

    function getCardId(address account, uint256 at) view public returns(uint256) {
        return gameRounds[account].cards[at];
    }

    function unlockMachine() public onlyOwner {   
        maintaining = false;
        emit MachineLocked(maintaining);
    }

    function lockMachine() public onlyOwner {
        maintaining = true;
        emit MachineLocked(maintaining);
    }

    // ***************************
    // For Admin Account ***********
    // ***************************
    function addStaffAccount(address account) public onlyOwner {
        _staffAccountSet.add(account);
    }

    function removeStaffAccount(address account) public onlyOwner {
        _staffAccountSet.remove(account);
    }

    function getStaffAccount(uint256 index) view public returns(address) {
        return _staffAccountSet.at(index);
    }

    function isStaffAccount(address account) view public returns(bool) {
        return _staffAccountSet.contains(account);
    }

    function staffAccountLength() view public returns(uint256) {
        return _staffAccountSet.length();
    }

    function transferAdministrator(address account) public onlyAdministrator {
        require(account != address(0), "Ownable: new owner is zero address");
        administrator = account;
    }

    // transfer this machine to artist
    function transferOwnership(address newOwner) public onlyAdministrator {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        owner = newOwner;
    }

    function removeOwnership() public onlyAdministrator {
        owner = address(0x0);
        artistAccount = address(0x0);
    }

    function changeArtistAccount(address account) public onlyOwner {
        require(account != address(0), "New artist is zero address");
        artistAccount = account;
    }

    function changeTeamAccount(address account) public onlyAdministrator {
        require(account != address(0), "New team account is zero address");
        teamAccount = account;
    }

    function changeLiquidityAccount(address account) public onlyAdministrator {
        require(account != address(0), "New liquidity account is zero address");
        liquidityAccount = account;
    }

    function changeShuffleCount(uint256 _shuffleCount) public onlyAdministrator {
        shuffleCount = _shuffleCount;
    }

    function banThisMachine() public onlyAdministrator {
        banned = true;
    }

    function unbanThisMachine() public onlyAdministrator {
        banned = false;
    }

    function changeMachineTitle(string memory title) public onlyOwner {
        machineTitle = title;
    }

    function changeMachineDescription(string memory description) public onlyOwner {
        machineDescription = description;
    }

    function changeMachineUri(string memory newUri) public onlyOwner {
        machineUri = newUri;
    }

    function cleanMachine() public onlyOwner returns(bool) {
        maintaining = true;
        banned = true;

        for (uint256 i = 0; i < cardIdCount(); i ++) {
            uint256 cardId = cardIdWithIndex(i);
            if (amountWithId[cardId] > 0) {
                nftToken.safeTransferFrom(address(this), owner, cardId, amountWithId[cardId], "Reset Machine");
                cardAmount = cardAmount.sub(amountWithId[cardId]);
                amountWithId[cardId] = 0;
            }
        }

        return true;
    }

    // This is a emergency function. you should not always call this function.
    function emergencyWithdrawCard(uint256 cardId) public onlyOwner {
        if (amountWithId[cardId] > 0) {
            nftToken.safeTransferFrom(address(this), owner, cardId, amountWithId[cardId], "Reset Machine");
            cardAmount = cardAmount.sub(amountWithId[cardId]);
            amountWithId[cardId] = 0;
        }
    }

    function isContract(address _addr) view private returns (bool){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    // Modifiers
    modifier onlyHuman() {
        require(!isContract(address(msg.sender)) && tx.origin == msg.sender, "Only for human.");
        _;
    }

    modifier onlyAdministrator() {
        require(address(msg.sender) == administrator, "Only for administrator.");
        _;
    }

    modifier onlyManager() {
        require(address(msg.sender) == manager || address(msg.sender) == administrator, "Only for manager.");
        _;
    }

    modifier onlyOwner() {
        require(address(msg.sender) == owner 
        || address(msg.sender) == administrator 
        || isStaffAccount(address(msg.sender)),
         "Only for owner.");
        _;
    }

    modifier unbanned() {
        require(!banned, "This machine is banned.");
        _;
    }
}