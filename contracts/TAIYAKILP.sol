// TAIYAKI -ETH LP
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract TAIYAKILP is ERC20, Ownable, AccessControl  {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC20("TAIYAKILP", "TAIYAKILP") public {
        uint8 decimals = 18;
        _setupDecimals(decimals);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());

        _mint(msg.sender, 5e20);
    }

    function mint(address to, uint256 value) public {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        _mint(to, value);
    }

}