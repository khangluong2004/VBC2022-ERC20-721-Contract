// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.0;

import "./ERC721_v2.sol";

contract Deployer {
    event Deployed(address MintERC20);
    mapping(uint256 => bool) private _exists;
    mapping(address => uint256) public get_salt;
    mapping(uint256 => address) public get_address;
    uint256 public latest_salt;
    address[] public deployed_addresses;



    //Still need the address of the Deploy contract to be the same (using CREATE (nonce, user account)).
    function deploy(uint256 _salt, address[] memory _admins) public returns(address) {
        require(_exists[_salt] == false, "Used address");
        ERC721_v2 MintERC721 = new ERC721_v2{salt: bytes32(abi.encodePacked(_salt))}("Tests", "TST", _admins);
        _exists[_salt] = true;
        latest_salt = _salt;

        address new_contract = address(MintERC721);
        get_salt[new_contract] = _salt;
        get_address[_salt] = new_contract;
        deployed_addresses.push(new_contract);

        emit Deployed(new_contract);
        return new_contract;
    }

}