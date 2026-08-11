pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

  // 1-based holder indexes (0 means "not in list")
  address[] private tokenHolders;
  mapping(address => uint256) private holderIndex;
  mapping(address => mapping(address => uint256)) private allowances;
  mapping(address => uint256) private withdrawableDividends;

  function _addHolder(address account) private {
    if (holderIndex[account] == 0) {
      tokenHolders.push(account);
      holderIndex[account] = tokenHolders.length;
    }
  }

  function _removeHolder(address account) private {
    uint256 index = holderIndex[account];
    if (index == 0) {
      return;
    }
    uint256 lastIndex = tokenHolders.length;
    address lastHolder = tokenHolders[lastIndex - 1];
    tokenHolders[index - 1] = lastHolder;
    holderIndex[lastHolder] = index;
    tokenHolders.pop();
    holderIndex[account] = 0;
  }

  function _transfer(address from, address to, uint256 value) private {
    require(to != address(0));
    bool toWasEmpty = balanceOf[to] == 0;
    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);

    if (from != to) {
      if (balanceOf[from] == 0) {
        _removeHolder(from);
      }
      if (value > 0 && toWasEmpty) {
        _addHolder(to);
      }
    }
  }

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    _transfer(msg.sender, to, value);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    allowances[msg.sender][spender] = value;
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    allowances[from][msg.sender] = allowances[from][msg.sender].sub(value);
    _transfer(from, to, value);
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0);
    if (balanceOf[msg.sender] == 0) {
      _addHolder(msg.sender);
    }
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
  }

  function burn(address payable dest) external override {
    require(dest != address(0));
    uint256 amount = balanceOf[msg.sender];
    require(amount > 0);
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);
    _removeHolder(msg.sender);
    dest.transfer(amount);
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return tokenHolders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index == 0 || index > tokenHolders.length) {
      return address(0);
    }
    return tokenHolders[index - 1];
  }

  function recordDividend() external payable override {
    require(msg.value > 0);
    uint256 supply = totalSupply;
    require(supply > 0);
    uint256 holderCount = tokenHolders.length;
    for (uint256 i = 0; i < holderCount; i++) {
      address holder = tokenHolders[i];
      uint256 share = msg.value.mul(balanceOf[holder]).div(supply);
      withdrawableDividends[holder] = withdrawableDividends[holder].add(share);
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return withdrawableDividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    require(dest != address(0));
    uint256 amount = withdrawableDividends[msg.sender];
    require(amount > 0);
    withdrawableDividends[msg.sender] = 0;
    dest.transfer(amount);
  }
}