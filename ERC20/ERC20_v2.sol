// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/**
 * @title SampleERC20
 * @dev Create a sample ERC20 standard token
 */
contract ERC20_v2 is ERC20 {
    mapping (address => bool) public admins;

    constructor(string memory tokenName, string memory tokenSymbol, address[] memory _admins) ERC20(tokenName, tokenSymbol) {
        for (uint i = 0; i < _admins.length; i++){
            admins[_admins[i]] = true;
            _mint(_admins[i], 10**uint(decimals()));
        }
    }

    modifier only_admin(){
        require(admins[msg.sender] == true, "Need to be an admin");
        _;
    }

    function change_admins(address acc, bool allow) public only_admin{
        admins[acc] = allow;
    }

    function mint(uint256 amount) public only_admin{
        _mint(msg.sender, amount);
    }
    
}