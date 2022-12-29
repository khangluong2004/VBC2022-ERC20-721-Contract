// SPDX-License-Identifier: MIT 

pragma solidity >=0.7.0 <0.9.0;


import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";


//Additional interface for mintable ERC721 token
interface MintIERC721 is IERC721 {
    function mint(uint256 tokenId, string memory _tokenURI) external;
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
/**
 * @title SampleERC721
 * @dev Create a sample ERC721 standard token
 */
contract BridgeERC721_v2 is ERC165, IERC721Receiver {
    mapping (address => bool) public admins;
    mapping (address => bool) public super_admins;
    //TokenId => Approved To_address
    mapping (uint256 => address) private _approved;

    event TransactMultiTokens(address indexed from, address indexed to, uint256[] tokenIds, bool is_lock);


    constructor(address[] memory _super_admins) {
        super_admins[msg.sender] = true;
        for (uint32 i=0; i < _super_admins.length; i++){
            super_admins[_super_admins[i]] = true;
        }
    }
    

    //ADMIN ROLES:

    modifier admin_approved(uint256[] memory token_ids){
        for (uint256 i = 0; i < token_ids.length; i++){
            require(_approved[token_ids[i]] == msg.sender, "Await for admin's approval");
        }
        _;
    }

    modifier only_admin(){
        require(admins[msg.sender] == true || super_admins[msg.sender] == true, "Need to be admin");
        _;
    }

    modifier only_super_admin(){
        require(super_admins[msg.sender] == true, "Need to be super admin");
        _;
    }


    function change_admins(address acc, bool allow) public only_super_admin{
        admins[acc] = allow;
    }

    function set_multiple_approvals(address [] memory tos, uint256[][] memory token_ids) public only_admin{
        require(tos.length == token_ids.length, "Invalid array lengths");
        for (uint32 i = 0; i < token_ids.length; i++){
            _set_approvals(tos[i], token_ids[i]);
        }
    } 

    function _set_approvals(address to, uint256[] memory token_ids) private {
        for (uint256 i = 0; i < token_ids.length; i++){
            _approved[token_ids[i]] = to;
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

    
    // Need to be called by owner & approved(All)
    function lock_multiples(uint256[] memory tokenIds, address from_contract_add, address to) public {
        MintIERC721 caller_contract = MintIERC721(from_contract_add);
        for (uint i = 0; i < tokenIds.length; i++){
            caller_contract.safeTransferFrom(msg.sender, address(this), tokenIds[i]);
        }
        emit TransactMultiTokens(msg.sender, to, tokenIds, true);
    }



    //Need to be approved by admins & add bridge SC as ERC721 admin
    function unlock_multiples(address from, uint256[] memory tokenIds, string[] memory tokenURIs, address to_contract_add) public admin_approved(tokenIds){
        require(tokenIds.length == tokenURIs.length, "Lengths of the 2 arrays are not equal");
        MintIERC721 caller_contract = MintIERC721(to_contract_add);
        for (uint32 i = 0; i < tokenIds.length; i++){
            uint256 tokenId = tokenIds[i];
            string memory _tokenURI = tokenURIs[i];
            try caller_contract.ownerOf(tokenId) returns (address owner) {
                require(owner == address(this), "Token is not locked");
            } catch {
                caller_contract.mint(tokenId, _tokenURI);
            }
            caller_contract.safeTransferFrom(address(this), msg.sender, tokenId);
            _approved[tokenId] = address(0);
        }
        emit TransactMultiTokens(from, msg.sender, tokenIds, false);
    }

}