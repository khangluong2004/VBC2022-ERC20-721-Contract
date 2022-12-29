// SPDX-License-Identifier: MIT 

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";


/**
 * @title SampleERC721
 * @dev Create a sample ERC721 standard token
 */
contract ERC721_v2 is ERC721URIStorage {
    mapping (address => bool) public admins; 
    mapping (string => bool) private _usedURI;


    constructor(string memory tokenName, string memory tokenSymbol, address[] memory _admins) ERC721(tokenName, tokenSymbol) {
        admins[msg.sender] = true;
        for (uint8 i = 0; i < _admins.length; i++){
            admins[_admins[i]] = true;
        }
    }

    modifier only_admin(){
        require(admins[msg.sender] == true, "Need to be an admin");
        _;
    }

    function change_admins(address acc, bool allow) public only_admin{
        admins[acc] = allow;
    }


    function mint(uint256 tokenId, string memory _tokenURI) public only_admin {
        require(_usedURI[_tokenURI] == false, "Minted URI");
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        _usedURI[_tokenURI] = true;
    }

}