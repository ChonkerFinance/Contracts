// Chonker GachaChonk Machine Manager contract
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./ChonkMachine.sol";

contract ChonkMachineManager is UUPSUpgradeable, OwnableUpgradeable, AccessControlUpgradeable {
    
    using SafeMath for uint256;

    bytes32 public constant STAFF_ROLE = keccak256("STAFF_ROLE");
    bytes32 public constant ARTIST_ROLE = keccak256("ARTIST_ROLE");

    address public teamAccount;
    address public liquidityAccount;
    address public nftAddress;
    address public taiyakiAddress;
    address public wethAddress;
    
    /* Gachapon Machine Options */
    uint256[8][] public options;     // [Team?, ETH-Spin?, TaiyakiLP %, Chonk Buyback %, Chonk LP %, Team Funds %, Artist Funds%, Burn %]

    uint256 lastMachineIdx;

    mapping(address => ChonkMachine) public machines;
    address[] public machineIndices;

    event MachineAdded(uint256 id, address addr, string name, string description, uint256 option_idx, uint256 price, address owner);
    
    function initialize(address _team, address _liquidityAccount, address _nft, address _taiyaki, address _weth) public  initializer {
        __Ownable_init();
        __AccessControl_init();

        teamAccount = _team;
        liquidityAccount = _liquidityAccount;
        nftAddress = _nft;
        taiyakiAddress = _taiyaki;
        wethAddress = _weth;
        lastMachineIdx = 0;

        _initOptions();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(STAFF_ROLE, msg.sender);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _initOptions() internal {
        options.push([1, 1, 40, 40,  0, 20,  0,  0]);
        options.push([1, 0, 40, 40,  0, 20,  0,  0]);
        options.push([1, 0, 80,  0,  0, 20,  0,  0]);
        options.push([1, 0,  0,  0,  0, 20,  0, 80]);
        options.push([1, 1,  0,  0, 80, 20,  0,  0]); 
        options.push([0, 1, 20,  0,  0, 20, 60,  0]);
        options.push([0, 0, 20,  0,  0, 20, 60,  0]);
    }

    function getOption(uint256 idx) public view returns (uint256[8] memory) {
        require(idx < options.length, "invalid idx");
        return options[idx];
    }

    function getOptionLength() public view returns (uint256) {
        return options.length;
    }

    function addMachine(string calldata _title, string calldata _description, uint256 _option_idx, uint256 _price, address _owner) external {
        require(hasRole(STAFF_ROLE, msg.sender), "Must be staff to add machine");
        require(hasRole(ARTIST_ROLE, _owner) || hasRole(STAFF_ROLE, _owner), "Machine Owner must be artist or staff");
        require(_option_idx < options.length, "Invalid option idx");

        uint256[8] memory option = getOption(_option_idx);
        
        ChonkMachine m = new ChonkMachine(
            lastMachineIdx,
            _title,
            _description,
            _price,
            _owner,
            owner(),
            teamAccount,
            liquidityAccount
        );

        m.setupMachineOption(_option_idx, option);
        m.setupTokenAddresses(nftAddress, taiyakiAddress, wethAddress);
        
        machines[address(m)] = m;
        machineIndices.push(address(m));

        emit MachineAdded(lastMachineIdx, address(m), _title, _description, _option_idx, _price, _owner);

        lastMachineIdx ++;
    }

    function addStaffAccount(address account) public {
        require(account != address(0), "staff is zero address");
        grantRole(STAFF_ROLE, account);
    }

    function removeStaffAccount(address account) public {
        require(account != address(0), "staff is zero address");
        revokeRole(STAFF_ROLE, account);
    }

    function isStaff(address account) public view returns(bool) {
        return hasRole(STAFF_ROLE, account);
    }

    function transferAdministrator(address account) public onlyOwner {
        require(account != address(0), "new administrator is zero address");
        
        grantRole(STAFF_ROLE, account);
        grantRole(DEFAULT_ADMIN_ROLE, account);

        revokeRole(STAFF_ROLE, msg.sender);
        revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);

        transferOwnership(account);
    }

    function isAdministrator(address account) public view returns(bool) {
        return account == owner();
    }

    function changeTokenAddress(address _nft, address _taiyaki) public onlyOwner {
        nftAddress = _nft;
        taiyakiAddress = _taiyaki;
    }

    function changeTeamAccount(address account) public onlyOwner {
        require(account != address(0), "New team account is zero address");
        teamAccount = account;
    }

    function changeLiquidityAccount(address account) public onlyOwner {
        require(account != address(0), "New liquidity account is zero address");
        liquidityAccount = account;
    }

    function getPaymentAccounts() public view returns(address, address) {
        return (teamAccount, liquidityAccount);
    }

    function changeMachineOption(address m_address, uint256 _option_idx) public {
        ChonkMachine machine = machines[m_address];
        require(machine.isStaffAccount(msg.sender), "only for staff account");
        
        machine.setupMachineOption(_option_idx, options[_option_idx]);
    }
}