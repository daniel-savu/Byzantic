pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DaiMock is ERC20 {

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

}