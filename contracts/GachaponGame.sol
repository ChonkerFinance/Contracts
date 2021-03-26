// Chonker Gachapon Game contract
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface IChonkNFT {
    function safeTransferFrom(address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data) external;
    function mint(address to, uint256 id, uint256 amount) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
}

contract GachaponGame is ReentrancyGuard, Pausable, Ownable, AccessControl {
    
    using SafeMath for uint256;

    bytes32 public constant TEAM_ROLE = keccak256("TEAM_ROLE");
    bytes32 public constant ARTIST_ROLE = keccak256("ARTIST_ROLE");

     /** Machine Struct */
    struct Machine { 
        address artist;
        address owner;
        bool locked;
        uint256 rate;
        uint256 option_idx; 
        uint256[6] amounts;
        uint256 total_spins;
        uint256 total_earnings;
        uint256 total_nfts;
        mapping(uint256 => uint256) nfts;
    }

    /* Team Address */
    address public teamAddress;

    /* NFT Token Address */
    address public nftAddress;

    /* Gachapon Machine Options */
    uint256[8][] public options;     // [Team?, ETH-Spin?, TaiyakiLP %, Chonk Buyback %, Chonk LP %, Team Funds %, Artist Funds%, Burn %]

    /** Machine Mapping */
    mapping(uint256 => Machine) machines; 

    uint256 lastMachineIdx;



    /*****************************************************************
    /*********************  Events 
    *****************************************************************/

    event MachineAdded(uint256 id, uint256 option_idx, uint256 rate, bool locked);
    event MachineUpdated(uint256 id, uint256 rate, uint256 option_id);
    event MachineDeleted(uint256 id);
    event MachineLocked(uint256 id, bool locked);

    event NFTAdded(uint256 m_id, uint256 id, uint256 amount);       



    constructor(address _team, address _nft) public {
        teamAddress = _team;
        nftAddress = _nft;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(TEAM_ROLE, _msgSender());

        lastMachineId = 0;

        options.push([1, 1, 40, 40,  0, 20,  0,  0]);
        options.push([1, 0, 40, 40,  0, 20,  0,  0]);
        options.push([1, 0, 80,  0,  0, 20,  0,  0]);
        options.push([1, 0,  0,  0,  0, 20,  0, 80]);
        options.push([1, 1,  0,  0, 80, 20,  0,  0]); 
        options.push([0, 1, 20,  0,  0, 20, 60,  0]);
        options.push([0, 0, 20,  0,  0, 20, 60,  0]);
    }


    function getOptionLength() public view returns (uint256) {
        return options.length;
    }

    function getOption(uint256 idx) public view returns (uint256[8] memory) {
        require(idx < getOptionLength(), "invalid idx");

        return options[idx];
    }

    function getMachineLength() public view returns (uint256) {
        return machines.length;
    }

    function addMachine(uint256 _option_idx, uint256 _rate, bool _locked) external nonReentrant whenNotPaused returns(uint256) {
        require(hasRole(TEAM_ROLE, msg.sender), "Must be admin to add machine");
        require(_option_idx < getOptionLength(), "Invalid option idx");
        
        Machine memory m;
        m.aritst = msg.sender;
        m.owner = msg.sender;
        m.locked = _locked;
        m.rate = _rate;
        m.option_idx = _option_idx;
        m.amounts = new uint256[](6);

        machines[lastMachineIdx] = m;
        lastMachineIdx ++;

        emit MachineAdded(lastMachineIdx-1, _option_idx, _rate, _locked);
    }

    function getMachine(uint256 _idx) external returns (address, address, bool, uint256, uint256, uint256, uint256, uint256, uint256) {
        Machine storage m = machines[_idx];
        return (
            m.artist,
            m.owner,
            m.locked,
            m.rate,
            m.option_idx,
            m.amounts,
            m.total_spins,
            m.total_earnings,
            m.total_nfts
        );
    }

    function getMachineNFT(uint256 _m_idx, uint256[] memory _nft_ids) public returns (uint256[] memory) {
        Machine storage m = machines[_m_idx];
        require(m.artist != address(0x0),  "invalid machine id");
    
        uint[] memory nft_balances = new uint[](_nft_ids.length);
        for(uint i = 0; i < _nft_ids.length; i++) {
            nft_balances[i] = m.nfts[_nft_ids[i]];
        }
        return nft_balances;
    }

    function updateMachineOption(uint256 _m_idx, uint256 _option_idx) external nonReentrant whenNotPaused {
        Machine storage m = machines[_m_idx];
        require(m.artist != address(0x0),  "invalid machine id");
        require(
            hasRole(TEAM_ROLE, msg.sender) 
            || (hasRole(ARTIST_ROLE, msg.sender && m.owner == msg.sender)),
            "Must be admin or owner can update machine");

        m.option_idx = _option_idx;

        emit MachineUpdated(_m_idx, m.rate, _option_idx);
    }

    function updateMachineRate(uint256 _m_idx, uint256 _rate) external nonReentrant whenNotPaused {
        Machine storage m = machines[_m_idx];
        require(m.artist != address(0x0),  "invalid machine id");
        require(
            hasRole(TEAM_ROLE, msg.sender) 
            || (hasRole(ARTIST_ROLE, msg.sender && m.owner == msg.sender)),
            "Must be admin or owner can update machine");

        m.rate = _rate;

        emit MachineUpdated(_m_idx, _rate, m.option_idx);
    }

    function updateMachineLocked(uint256 _m_idx, bool _locked) external nonReentrant whenNotPaused {
        Machine storage m = machines[_m_idx];
        require(m.artist != address(0x0),  "invalid machine id");
        require(
            hasRole(TEAM_ROLE, msg.sender) 
            || (hasRole(ARTIST_ROLE, msg.sender && m.owner == msg.sender)),
            "Must be admin or owner can update machine");

        m.locked = _locked;

        emit MachineLocked(_m_idx, _locked);
    }

    function deleteMachine(uint256 _m_idx) external nonReentrant whenNotPaused {
        require(machines[_m_idx].artist != address(0x0),  "invalid machine id");

        delete machines[_m_idx];
        
        emit MachineDeleted(_m_idx);
    }

    function removeOwner(uint256 _m_idx) external nonReentrant whenNotPaused onlyOwner{
        Machine storage m = machines[_m_idx];
        require(m.artist != address(0x0),  "invalid machine id");

        m.artist =0x000000000000000000000000000000000000dEaD;
        m.owner = 0x000000000000000000000000000000000000dEaD;
    }


    function loadNFT(uint256 _m_idx, uint256 _nft_id, uint256 _amount, bool _mint) external nonReentrant whenNotPaused {
        Machine storage m = machines[_m_idx];
        require(m.artist != address(0x0),  "invalid machine id");
        require(
            hasRole(TEAM_ROLE, msg.sender) 
            || (hasRole(ARTIST_ROLE, msg.sender && m.owner == msg.sender)),
             "Must be admin or owner can load nft to machine");
  
        IChonkNFT nft = IChonkNFT(nftAddress);
        if(_mint) {
            nft.mint(address(this), _nft_id, _amount);
        }else{
            require(nft.balanceOf(msg.sender, _nft_id) >= _amount, "You do not have enough tokens to load");

            nft.safeTransferFrom(msg.sender, address(this), _nft_id, _amount, "");
        }
        m.nfts[_nft_id] = _amount;

        emit NFTAdded(_m_idx, _nft_id, _amount);
    }

    function play(uint256 _m_idx, uint256 _count) external {

    }

     // fallback- receive Ether
    function () public payable {
    
    }

}