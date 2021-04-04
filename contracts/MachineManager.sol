// Chonker Gachapon Game contract
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
}

contract MachineManager is ReentrancyGuard, Pausable, Ownable, AccessControl {
    
    using SafeMath for uint256;

    bytes32 public constant TEAM_ROLE = keccak256("TEAM_ROLE");
    bytes32 public constant ARTIST_ROLE = keccak256("ARTIST_ROLE");

     /** Machine Struct */
    struct Machine { 
        address artist;
        address owner;
        string name;
        string description;
        bool locked;
        uint256 rate;
        uint256 option_idx; 
        uint256[6] amounts;
        uint256 total_spins;
        uint256 total_earnings;
        uint256 total_nfts;
        uint256[] nft_ids;
        mapping(uint256 => uint256) nfts;
    }

    /* Team Address */
    address public teamAddress;

    /* NFT Token Address */
    address public nftAddress;

    /* Taiyaki Token Address */
    address public taiyakiAddress;

    /* Gachapon Machine Options */
    uint256[8][] public options;     // [Team?, ETH-Spin?, TaiyakiLP %, Chonk Buyback %, Chonk LP %, Team Funds %, Artist Funds%, Burn %]

    /** Machine Mapping */
    mapping(uint256 => Machine) machines; 

    uint256 lastMachineIdx;
    uint256 totalMachines;

    uint randNonce = 0;

    /*****************************************************************
    /*********************  Events 
    *****************************************************************/

    event MachineAdded(uint256 id, string name, string description, uint256 option_idx, uint256 rate, bool locked);
    event MachineOptionUpdated(uint256 id, uint256 option_id);
    event MachineRateUpdated(uint256 id, uint256 rate);
    event MachineNameUpdated(uint256 id, string name);
    event MachineDescriptionUpdated(uint256 id, string description);
    event MachineDeleted(uint256 id);
    event MachineLocked(uint256 id, bool locked);

    event NFTAdded(uint256 m_id, uint256 id, uint256 amount);       

    event GamePlayed(uint256 m_id, uint256 count);

    constructor(address _team, address _nft, address _taiyaki) public {
        teamAddress = _team;
        nftAddress = _nft;
        taiyakiAddress = _taiyaki;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(TEAM_ROLE, _msgSender());

        lastMachineIdx = 0;
        totalMachines = 0;

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
        return totalMachines;
    }

    function addMachine(string calldata _name, string calldata _description, uint256 _option_idx, uint256 _rate, bool _locked) external nonReentrant whenNotPaused returns(uint256) {
        require(hasRole(TEAM_ROLE, msg.sender), "Must be admin to add machine");
        require(_option_idx < getOptionLength(), "Invalid option idx");
        
        Machine memory m;
        m.artist = msg.sender;
        m.owner = msg.sender;
        m.name = _name;
        m.description = _description;
        m.locked = _locked;
        m.rate = _rate;
        m.option_idx = _option_idx;
        m.nft_ids = new uint256[](0);

        machines[lastMachineIdx] = m;
        lastMachineIdx ++;

        emit MachineAdded(lastMachineIdx-1, _name, _description, _option_idx, _rate, _locked);
    }

    function getMachine(uint256 _idx) external view returns (address, address, string memory, string memory, bool, uint256, uint256, uint256[6] memory, uint256, uint256, uint256) {
        Machine memory m = machines[_idx];
        return (
            m.artist,
            m.owner,
            m.name,
            m.description,
            m.locked,
            m.rate,
            m.option_idx,
            m.amounts,
            m.total_spins,
            m.total_earnings,
            m.total_nfts
        );
    }

    function getMachineNFT(uint256 _m_idx, uint256[] calldata _nft_ids) external view returns (uint256[] memory) {
        Machine storage m = machines[_m_idx];
        require(m.artist != address(0x0),  "invalid machine id");
        require(m.nft_ids.length >= _nft_ids.length, "invalid ids");
    
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
            || (hasRole(ARTIST_ROLE, msg.sender) && m.owner == msg.sender),
            "Must be admin or owner can update machine");

        m.option_idx = _option_idx;

        emit MachineOptionUpdated(_m_idx, _option_idx);
    }

    function updateMachineRate(uint256 _m_idx, uint256 _rate) external nonReentrant whenNotPaused {
        Machine storage m = machines[_m_idx];
        require(m.artist != address(0x0),  "invalid machine id");
        require(
            hasRole(TEAM_ROLE, msg.sender) 
            || (hasRole(ARTIST_ROLE, msg.sender) && m.owner == msg.sender),
            "Must be admin or owner can update machine");

        m.rate = _rate;

        emit MachineRateUpdated(_m_idx, _rate);
    }

    function updateMachineName(uint256 _m_idx, string calldata _name) external nonReentrant whenNotPaused {
        Machine storage m = machines[_m_idx];
        require(m.artist != address(0x0),  "invalid machine id");
        require(
            hasRole(TEAM_ROLE, msg.sender) 
            || (hasRole(ARTIST_ROLE, msg.sender) && m.owner == msg.sender),
            "Must be admin or owner can update machine");

        m.name = _name;

        emit MachineNameUpdated(_m_idx, _name);
    }

    function updateMachineDescription(uint256 _m_idx, string calldata _description) external nonReentrant whenNotPaused {
        Machine storage m = machines[_m_idx];
        require(m.artist != address(0x0),  "invalid machine id");
        require(
            hasRole(TEAM_ROLE, msg.sender) 
            || (hasRole(ARTIST_ROLE, msg.sender) && m.owner == msg.sender),
            "Must be admin or owner can update machine");

        m.description = _description;

        emit MachineDescriptionUpdated(_m_idx, _description);
    }

    function updateMachineLocked(uint256 _m_idx, bool _locked) external nonReentrant whenNotPaused {
        Machine storage m = machines[_m_idx];
        require(m.artist != address(0x0),  "invalid machine id");
        require(
            hasRole(TEAM_ROLE, msg.sender) 
            || (hasRole(ARTIST_ROLE, msg.sender) && m.owner == msg.sender),
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
            || (hasRole(ARTIST_ROLE, msg.sender) && m.owner == msg.sender),
             "Must be admin or owner can load nft to machine");
  
        IChonkNFT nft = IChonkNFT(nftAddress);
        if(_mint) {
            nft.mint(address(this), _nft_id, _amount);
        }else{
            require(nft.balanceOf(msg.sender, _nft_id) >= _amount, "You do not have enough tokens to load");

            nft.safeTransferFrom(msg.sender, address(this), _nft_id, _amount, "");
        }

        m.nfts[_nft_id] += _amount;
        m.total_nfts += _amount;

        bool isExist = false;
        for(uint i = 0; i < m.nft_ids.length; i ++) {
            if(m.nft_ids[i] == _nft_id) {
                isExist = true; break;
            }
        }
        if(!isExist) {
            m.nft_ids.push(_nft_id);
        }

        emit NFTAdded(_m_idx, _nft_id, _amount);
    }



    function play(uint256 _m_idx, uint256 _count) payable public nonReentrant whenNotPaused {
        Machine storage m = machines[_m_idx];
        require(m.artist != address(0x0),  "invalid machine id");
        require(m.locked == false,  "machine is locked now");
        require(m.total_nfts >= _count, "insufficient nft balance");

        uint256 amount = m.rate.mul(_count);
        uint256[8] memory option = getOption(m.option_idx);

        if(option[1] == 1) {  // ETH spin
            require(amount >= msg.value, "insufficient eth amount");
        }else {               // Taiyaki Spin
            IERC20 taiyakiToken = IERC20(taiyakiAddress);
            uint256 allowance = taiyakiToken.allowance(msg.sender, address(this));
            require(allowance >= amount, "Check the TAIYAKI token allowance");
            taiyakiToken.transferFrom(msg.sender, address(this), amount);
        }


        //[Team?, ETH-Spin?, TaiyakiLP %, Chonk Buyback %, Chonk LP %, Team Funds %, Artist Funds%, Burn %]
        for (uint i = 0 ; i < 6 ; i ++) {
            if (option[i + 2] != 0) {
                m.amounts[i] += amount.mul(option[i + 2]).div(100);
            }
        }

        // NFT Random select
        uint256[] memory ids = new uint256[](_count);
        uint256[] memory amounts = new uint256[](_count);
        uint selected = 0;
        while(selected < _count) {
            uint256 rand_idx = random(m.nft_ids.length);
            uint256 rand_id = m.nft_ids[rand_idx];
            if(m.nfts[rand_id] > 0) {
                ids[selected] = rand_id;
                amounts[selected] = 1;
                selected ++;
                m.nfts[rand_id]--;
                m.total_nfts--;
            }
        }

        IChonkNFT(nftAddress).safeBatchTransferFrom(address(this), msg.sender, ids, amounts, "");

        emit GamePlayed(_m_idx, _count);
    }

    function withdrawMachine(uint256 _m_idx) public onlyOwner nonReentrant whenNotPaused {
        Machine storage m = machines[_m_idx];
        require(m.artist != address(0x0),  "invalid machine id");
       
        /** amounts[0] : Taiyaki LP */
        /** amounts[1] : Chonk Buyback */
        /** amounts[2] : Chonk LP */
        /** amounts[3] : Team Funds */
        /** amounts[4] : Artist Funds */
        /** amounts[5] : Burn */
    }

    function random(uint256 maxVal) internal returns (uint256) {
        randNonce ++;
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, randNonce))).mod(maxVal);
    }

     // fallback- receive Ether
    receive () external payable {
    
    }

}