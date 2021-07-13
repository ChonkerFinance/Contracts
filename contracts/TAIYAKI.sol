// TAIYAKI Token Contract - Chonker.Finance
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract TAIYAKI is ERC20, Ownable, AccessControl  {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC20("TAIYAKI", "TAIYAKI") {
        
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());

        _mint(0xFA3916579cFD0F4B8193B144fc9D6Ce14dfdb082, 1.6e21);
    }

    function mint(address to, uint256 value) public {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        _mint(to, value);
    }

}