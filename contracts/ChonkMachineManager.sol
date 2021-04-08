// Chonker GachaChonk Machine Manager contract
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./ChonkMachine.sol";

contract ChonkMachineManager is ReentrancyGuard, Ownable, AccessControl {
    
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
    event MachineOptionUpdated(address addr, uint256 option_id);
    event MachineDeleted(address addr);
    
    constructor(address _team, address _liquidityAccount, address _nft, address _taiyaki, address _weth) public {
        teamAccount = _team;
        liquidityAccount = _liquidityAccount;
        nftAddress = _nft;
        taiyakiAddress = _taiyaki;
        wethAddress = _weth;
        lastMachineIdx = 0;

        _initOptions();

        _setupRole(STAFF_ROLE, owner());
    }

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

    function addMachine(string calldata _title, string calldata _description, uint256 _option_idx, uint256 _price, address _owner) 
        external nonReentrant  returns(uint256) {

        require(hasRole(STAFF_ROLE, msg.sender), "Must be staff to add machine");
        require(hasRole(ARTIST_ROLE, _owner), "Machine Owner must be artist");
        require(_option_idx < options.length, "Invalid option idx");

        uint256[8] memory option = getOption(_option_idx);
        
        ChonkMachine m = new ChonkMachine(
            lastMachineIdx,
            _title,
            _description,
            IChonkNFT(nftAddress),
            IERC20(option[1] == 1 ? wethAddress : taiyakiAddress),
            _price,
            option,
            _owner,
            owner(),
            teamAccount,
            liquidityAccount
        );
        
        machines[address(m)] = m;
        machineIndices.push(address(m));

        emit MachineAdded(lastMachineIdx, address(m), _title, _description, _option_idx, _price, _owner);

        lastMachineIdx ++;
    }

    function deleteMachine(address m_address) external nonReentrant  onlyOwner {
        require(machines[m_address].owner() != address(0x0),  "invalid machine address");
        
        uint machineLength = machineIndices.length;
        ChonkMachine machine = machines[m_address];
        require(machine.cleanMachine(), "failed to clean machine");
        
        uint indexToBeDeleted;
        for (uint i=0; i<machineLength; i++) {
            if (machineIndices[i] == m_address) {
                indexToBeDeleted = i;
                break;
            }
        }

        if (indexToBeDeleted != machineLength-1) {
            machineIndices[indexToBeDeleted] = machineIndices[machineLength-1];
        }

        delete machines[m_address];
        machineIndices.pop();

        emit MachineDeleted(m_address);
    }


    function addStaffAccount(address account) public nonReentrant onlyOwner {
        require(account != address(0), "staff is zero address");
        grantRole(STAFF_ROLE, account);
        for(uint256 i = 0; i < machineIndices.length; i++) {
            (bool success, ) = machineIndices[i].delegatecall(
                abi.encodeWithSignature("addStaffAccount(address)", account)
            );
        }
    }

    function removeStaffAccount(address account) public nonReentrant onlyOwner {
        require(account != address(0), "staff is zero address");
        revokeRole(STAFF_ROLE, account);
        for(uint256 i = 0; i < machineIndices.length; i++) {
            (bool success, ) = machineIndices[i].delegatecall(
                abi.encodeWithSignature("removeStaffAccount(address)", account)
            );
        }
    }

    function transferAdministrator(address account) public nonReentrant onlyOwner {
        require(account != address(0), "new administrator is zero address");
        
        grantRole(STAFF_ROLE, account);

        for(uint256 i = 0; i < machineIndices.length; i++) {
            (bool success, ) = machineIndices[i].delegatecall(
                abi.encodeWithSignature("transferAdministrator(address)", account)
            );
        }
        transferOwnership(account);
    }

    function changeTeamAccount(address account) public nonReentrant onlyOwner {
        require(account != address(0), "New team account is zero address");

        for(uint256 i = 0; i < machineIndices.length; i++) {
            (bool success, ) = machineIndices[i].delegatecall(
                abi.encodeWithSignature("changeTeamAccount(address)", account)
            );
        }
    }

    function changeLiquidityAccount(address account) public nonReentrant onlyOwner {
        require(account != address(0), "New liquidity account is zero address");

        for(uint256 i = 0; i < machineIndices.length; i++) {
            (bool success, ) = machineIndices[i].delegatecall(
                abi.encodeWithSignature("changeLiquidityAccount(address)", account)
            );
        }
    }
}