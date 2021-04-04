// Chonker Gachapon Machine contract 
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";


interface IChonkNFT {
  function safeTransferFrom(address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data) external;
  function balanceOf(address account, uint256 id) external view returns (uint256);
}

contract GachaMachineOnMatic is Ownable, AccessControl {
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

    /***********************************
     * @dev Configuration of this GameMachine
     ***********************************/
    uint256 public machineId;
    string public machineTitle;
    string public machineDescription;
    string public machineUri;
    // machine type. 0: Taiyaki machine, 1: ETH machine.
    uint256 public machineType = 1;
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

    /*******************************
     * something about rate, account, total amount
     *******************************/
    uint256 public forBuybackRate = 0;
    uint256 public forBurnRate = 0;
    uint256 public forArtistRate = 0;
    uint256 public forAgentRate = 0;

    uint256 public totalAmountForBuybackDoki;
    uint256 public totalAmountForBurn;
    uint256 public totalAmountForArtist;
    uint256 public totalAmountForReferrer;
    uint256 public totalAmountForDev;

    address public dokiBuybackAccount;
    address public azukiBurnAccount;
    address public artistAccount;
    address public agentAccount;
    EnumerableSet.AddressSet private _devAccountSet;
    // Currency of the game machine, like AZUKI, WETH, Chianbinders.
    IERC20 public currencyToken;
    IChonkNFT public nftToken;

    uint256 public playOncePrice;
    address public administrator;

    event AddCard(uint256 cardId, uint256 amount, uint256 cardAmount);
    event RemoveCard(uint256 card, uint256 removeAmount, uint256 cardAmount);
    event RunMachineSuccessfully(address account, uint256 times, uint256 playFee);

    constructor(uint256 _machineId, //machine id
                string memory _machineTitle, // machine title. will be used to initial machine description.
                IChonkNFT _momijiToken, // momiji token address
                IERC20 _currencyToken // currency address
                ) public {
        machineId = _machineId;
        nftToken = _momijiToken;
        currencyToken = _currencyToken;
        administrator = msg.sender;
        artistAccount = msg.sender;
        agentAccount = msg.sender;
        forArtistRate = 70; // ETH machine, ratio for artist is 70%
        forBuybackRate = 15; // 15% is used to buyback
        _setupMachineTitle(_machineTitle);
        _setupAccounts();
        _salt = uint256(keccak256(abi.encodePacked(_momijiToken, _currencyToken, block.timestamp))).mod(10000);
    }

    //setup title
    function _setupMachineTitle(string memory _title) private {
        machineTitle = _title;
        machineDescription = _title;
    }

    // setup dev account
    function _setupAccounts() private {
        _devAccountSet.add(0x7b3da3e4E923eeC82774ED38Dc92eC28Dfd69b9D);
        _devAccountSet.add(0x5F956ca9a2eD963Bf955E9e4337E0A4F1d2Dd8e9);
        dokiBuybackAccount = 0xc91ca8DC020F0135Df86c1D88d4CDC9caF9982Da;
        azukiBurnAccount = 0x6dC9950905BAcA54Ccc97e4A0D0F24D9611B46ef;
    }

    function setTokenRateForETHMachine(
        uint256 _forBuybackRate,
        uint256 _forArtistRate,
        uint256 _forAgentRate
    ) public onlyAdministrator {
        require(machineType == 1, "this machine is not ETH machine");
        forBurnRate == 0;
        forBuybackRate = _forBuybackRate;
        forArtistRate = _forArtistRate;
        forAgentRate = _forAgentRate;

        require(forBuybackRate
                .add(forBurnRate)
                .add(forArtistRate)
                .add(forAgentRate) < 100, "Bad Rate.");
    }

    /**
     * @dev Add cards which have been minted, and your owned cards
     * @param cardId. Card id you want to add.
     * @param amount. How many cards you want to add.
     */
    function addCard(uint256 cardId, uint256 amount) public onlyOwner unbanned {
        require(nftToken.balanceOf(msg.sender, cardId) >= amount, "You don't have enough Cards");
        nftToken.safeTransferFrom(msg.sender, address(this), cardId, amount, "Add Card");
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

        emit RunMachineSuccessfully(msg.sender, times, playFee);
    }

    /**
     * @param amount how much token will be needed and will be burned.
     */
    function _transferAndBurnToken(uint256 amount) private {
        // 1. For artist.
        uint256 forArtistAmount = 0;
        if (forArtistRate != 0) {
            forArtistAmount = amount.mul(forArtistRate).div(100);
            currencyToken.transferFrom(msg.sender, artistAccount, forArtistAmount);
            totalAmountForArtist = totalAmountForArtist.add(forArtistAmount);
        }
        // 2. for agent.
        uint256 forAgentAmount = 0;
        if (forAgentRate != 0) {
            forAgentAmount = amount.mul(forAgentRate).div(100);
            currencyToken.transferFrom(msg.sender, agentAccount, forAgentAmount);
            totalAmountForReferrer = totalAmountForReferrer.add(forAgentAmount);
        }

        uint256 forBuybackAmount = 0;
        if (forBuybackRate != 0) {
            forBuybackAmount = amount.mul(forBuybackRate).div(100);
            currencyToken.transferFrom(msg.sender, dokiBuybackAccount, forBuybackAmount);
            totalAmountForBuybackDoki = totalAmountForBuybackDoki.add(forBuybackAmount);
        }

        // 3. tansfer token remaining to dev account.
        uint256 remainingAmount = amount.sub(forArtistAmount).sub(forAgentAmount).sub(forBuybackAmount);
        uint256 devAccountAmount = _devAccountSet.length();
        uint256 transferAmount = remainingAmount.div(devAccountAmount);
        totalAmountForDev = totalAmountForDev.add(remainingAmount);

        for (uint256 i = 0; i < devAccountAmount; i ++) {
            address toAddress = _devAccountSet.at(i);
            currencyToken.transferFrom(msg.sender, toAddress, transferAmount);
        }
    }

    function _distributePrize() private {
        for (uint i = 0; i < gameRounds[msg.sender].times; i ++) {
            uint256 cardId = gameRounds[msg.sender].cards[i];
            require(amountWithId[cardId] > 0, "No enough cards of this kind in the Mchine.");

            nftToken.safeTransferFrom(address(this), msg.sender, cardId, 1, 'Your prize from Degacha');

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
        return uint256(keccak256(abi.encode(block.timestamp, block.difficulty, block.coinbase, block.gaslimit, seed, block.number))).mod(mod).add(seed).add(salt);
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
    }

    function lockMachine() public onlyOwner {
        maintaining = true;
    }

    // ***************************
    // For Dev Account ***********
    // ***************************
    function addDevAccount(address payable account) public onlyAdministrator {
        _devAccountSet.add(account);
    }

    function removeDevAccount(address payable account) public onlyAdministrator {
        _devAccountSet.remove(account);
    }

    function getDevAccount(uint256 index) view public returns(address) {
        return _devAccountSet.at(index);
    }

    function devAccountLength() view public returns(uint256) {
        return _devAccountSet.length();
    }

    function transferAdministrator(address account) public onlyAdministrator {
        require(account != address(0), "Ownable: new owner is zero address");
        administrator = account;
    }

    // transfer this machine to artist
    function transferOwnership(address newOwner) public override onlyAdministrator {
        super.transferOwnership(newOwner);
        artistAccount = newOwner;
    }

    function changeArtisAccount(address account) public onlyOwner {
        require(account != address(0), "New artist is zero address");
        artistAccount = account;
    }

    function changeAgentAccount(address account) public onlyAdministrator {
        require(account != address(0), "New referrer account is zero address");
        agentAccount = account;
    }

    function changeBuybackAddress(address account) public onlyAdministrator {
        require(account != address(0), "New referrer account is zero address");
        dokiBuybackAccount = account;
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

    function cleanMachine() public onlyOwner {
        require(msg.sender == administrator || msg.sender == owner(), "Only for administrator.");
        maintaining = true;
        banned = true;

        for (uint256 i = 0; i < cardIdCount(); i ++) {
            uint256 cardId = cardIdWithIndex(i);
            if (amountWithId[cardId] > 0) {
                nftToken.safeTransferFrom(address(this), owner(), cardId, amountWithId[cardId], "Reset Machine");
                cardAmount = cardAmount.sub(amountWithId[cardId]);
                amountWithId[cardId] = 0;
            }
        }
    }

    // This is a emergency function. you should not always call this function.
    function emergencyWithdrawCard(uint256 cardId) public onlyOwner {
        if (amountWithId[cardId] > 0) {
            nftToken.safeTransferFrom(address(this), owner(), cardId, amountWithId[cardId], "Reset Machine");
            cardAmount = cardAmount.sub(amountWithId[cardId]);
            amountWithId[cardId] = 0;
        }
    }

    // Modifiers
    modifier onlyHuman() {
        require(!address(msg.sender).isContract() && tx.origin == msg.sender, "Only for human.");
        _;
    }

    modifier onlyAdministrator() {
        require(address(msg.sender) == administrator, "Only for administrator.");
        _;
    }

    modifier unbanned() {
        require(!banned, "This machine is banned.");
        _;
    }
}