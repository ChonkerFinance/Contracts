// https://www.chonker.finance/
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Chonker is ERC20("CHONK", "CHONK") {
  constructor() public {
        _mint(0xc2A79DdAF7e95C141C20aa1B10F3411540562FF7, 28000000000000000000000);
  }
}