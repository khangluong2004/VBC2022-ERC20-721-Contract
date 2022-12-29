// SPDX-License-Identifier: MIT 

pragma solidity >=0.7.0 <0.9.0;


import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


//Additional interface for mintable ERC721 token
interface MintIERC721 is IERC721 {
    function mint(uint256 tokenId, string memory _tokenURI) external;
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
/**
 * @title SampleERC721
 * @dev Create a sample ERC721 standard token
 */
contract BridgeERC721_v3 is ERC165, IERC721Receiver {
    mapping (address => bool) public admins;
    mapping (address => bool) public super_admins;
    
    //From => to => tokenId => isLock => NumTransact (Uint256)
    mapping (address => mapping(address => mapping(uint256 => mapping(bool => uint256)))) public NumTransact;


    event TransactMultiTokens(address indexed from, address indexed to, uint256[] tokenIds, bool is_lock);


    constructor(address[] memory _super_admins) {
        super_admins[msg.sender] = true;
        for (uint32 i=0; i < _super_admins.length; i++){
            super_admins[_super_admins[i]] = true;
        }
    }
    
   

    //IERC165 
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    //The same function is in ERC721Holder (in utils/ folder of OpenZeppelin)
    function onERC721Received (
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4){
        return IERC721Receiver.onERC721Received.selector;
    }

    //Verify signature
    function check_signature(bytes32 messageHash, bytes memory signature) internal view returns(bool){
        bytes32 EthHash = ECDSA.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(EthHash, signature);
        return(admins[signer] || super_admins[signer]);
    }
    
    // Need to be called by owner & approved(All)
    function lock_multiples(uint256[] memory tokenIds, address from_contract_add, address to) public {
        MintIERC721 caller_contract = MintIERC721(from_contract_add);
        for (uint i = 0; i < tokenIds.length; i++){
            NumTransact[msg.sender][to][tokenIds[i]][true] += 1;
            caller_contract.safeTransferFrom(msg.sender, address(this), tokenIds[i]);
        }
        emit TransactMultiTokens(msg.sender, to, tokenIds, true);
        
    }



    //Need to be approved by admins & add bridge SC as ERC721 admin
    function unlock_multiples(address from, uint256[] memory tokenIds, string[] memory tokenURIs, address to_contract_add, bytes[] memory signatures) public {
        require(tokenIds.length == tokenURIs.length, "Lengths of the 2 arrays are not equal");
        MintIERC721 caller_contract = MintIERC721(to_contract_add);
        for (uint32 i = 0; i < tokenIds.length; i++){
            uint256 tokenId = tokenIds[i];
            string memory _tokenURI = tokenURIs[i];

            uint256 nonce = NumTransact[from][msg.sender][tokenIds[i]][false];
            bytes32 messageHash = keccak256(abi.encodePacked("unlock_multiples", from, msg.sender, tokenId, nonce));
            bool check = check_signature(messageHash, signatures[i]);
            require(check == true, "Fail to verify");

            try caller_contract.ownerOf(tokenId) returns (address owner) {
                require(owner == address(this), "Token is not locked");
            } catch {
                caller_contract.mint(tokenId, _tokenURI);
            }
            NumTransact[from][msg.sender][tokenIds[i]][false] += 1;
            caller_contract.safeTransferFrom(address(this), msg.sender, tokenId);
        }
        emit TransactMultiTokens(from, msg.sender, tokenIds, false);
    }

}