// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract GovernanceToken is ERC20Votes {
  uint256 public s_maxSupply = 100000000e18;
  address owner;

  constructor(address _owner) ERC20("CanaryToken", "CAT") ERC20Permit("CanaryToken") {
    owner = _owner;
  }

  // The functions below are overrides required by Solidity.

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override(ERC20Votes) {
    super._afterTokenTransfer(from, to, amount);
  }

  function mint(address _to, uint256 _amount) external {
    require(msg.sender == owner);
    _mint(_to, _amount);
  }

  function burn(address _to, uint256 _amount) external {
    require(msg.sender == owner);
    _burn(_to, _amount);
  }

  function _mint(address to, uint256 amount) internal override(ERC20Votes) {
    super._mint(to, amount);
  }

  function _burn(address account, uint256 amount) internal override(ERC20Votes) {
    super._burn(account, amount);
  }
}