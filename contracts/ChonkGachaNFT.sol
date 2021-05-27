// SPDX-License-Identifier: MIT
pragma solidity 0.6.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract ChonkNFT is ERC1155, AccessControl {
  using SafeMath for uint256;

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");


  constructor() public ERC1155("https://farm.chonker.finance/api/NFT/") {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  function mint(address to, uint256 id, uint256 amount) public {
    require(hasRole(MINTER_ROLE, _msgSender()), "Caller is not a minter");
    _mint(to, id, amount, "");
  }
    
  function burn(uint256 id, uint256 amount) public {
    _burn(_msgSender(), id, amount);
  }

}