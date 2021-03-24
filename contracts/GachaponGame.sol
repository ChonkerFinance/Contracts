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
  function balanceOf(address account, uint256 id) external view returns (uint256);
}

contract GachaponGame is ReentrancyGuard, Pausable, Ownable, AccessControl {
    
    using SafeMath for uint256;

    bytes32 public constant TEAM_ROLE = keccak256("TEAM_ROLE");
    bytes32 public constant ARTIST_ROLE = keccak256("ARTIST_ROLE");

    /* Team Address */
    address public teamAddress;

    /* Gachapon Machine Options */
    uint256[8][] public options;     // [Team?, ETH-Spin?, TaiyakiLP %, Chonk Buyback %, Chonk LP %, Team Funds %, Artist Funds%, Burn %]


    
    constructor(address _team) public {
        teamAddress = _team;

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

    

}