// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


/**
 * @title SampleERC20
 * @dev Create a sample ERC20 standard token
 */

interface MintableIERC20 is IERC20{
    function mint(uint256 amount) external;
}

contract BridgeERC20 {
    mapping (address => bool) public admins;
    mapping (address => bool) public super_admins;
    
    //From_address => To_address => isNative => isLock => Uint256 (Amounts)
    mapping (address => mapping(address => mapping(bool => mapping(bool => uint256)))) public TrackingAmounts;
    
    event TransactToken(address indexed from, address indexed to, uint256 indexed amount, bool is_native, bool is_lock);


    constructor(address[] memory _super_admins) payable {
        for (uint i=0; i < _super_admins.length; i++){
            super_admins[_super_admins[i]] = true;
        }
        
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

    //Verify signature
    function check_signature(bytes32 messageHash, bytes memory signature) public view returns(bool){
        bytes32 EthHash = ECDSA.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(EthHash, signature);
        return(admins[signer] || super_admins[signer]);
    }

    //Automatic receive - To transfer from 1 acc to the same acc - Web3 doesn't support subscription, code backend later
    receive() external payable {
        require(msg.value > 0);
        TrackingAmounts[msg.sender][msg.sender][true][true] += msg.value;
        emit TransactToken(msg.sender, msg.sender, msg.value, true, true);
    }

    
    //Receiver
    function receive_native(address to) public payable {
        require(msg.value > 0, "Transfer zero");
        TrackingAmounts[msg.sender][to][true][true] += msg.value;
        emit TransactToken(msg.sender, to, msg.value, true, true);
    }


    //Transfer Native
    function transfer_native(address from, uint256 amount, bytes memory signature) public payable {
        require(amount <= address(this).balance);
        uint256 nonce = TrackingAmounts[from][msg.sender][true][false];
        bytes32 messageHash = keccak256(abi.encodePacked("transfer_native", from, msg.sender, amount, nonce));
        bool check = check_signature(messageHash, signature);
        require(check == true, "Fail to verify");

        TrackingAmounts[from][msg.sender][true][false] += amount;
        (bool sent, ) = (msg.sender).call{value: amount}("");
        require(sent == true, "Fail to transfer");
        emit TransactToken(from, msg.sender, amount, true, false);
    }


    //Lock, require APPROVAL
    function lock(address from_contract_add, uint256 amount, address to) public {
        TrackingAmounts[msg.sender][to][false][true] += amount;
        IERC20 from_contract = IERC20(from_contract_add);
        bool success = from_contract.transferFrom(msg.sender, address(this), amount);
        require(success == true, "Can't lock");
        emit TransactToken(msg.sender, to, amount, false, true);
    }

    //Need to make Bridge an admin in ERC20 contract for minting
    //Unlock
    function unlock(address from, address to_contract_add, uint256 amount, bytes memory signature) public {
        address to = msg.sender;
        uint256 nonce = TrackingAmounts[from][to][false][false];
        bytes32 messageHash = keccak256(abi.encodePacked("unlock", from, to, amount, nonce));
        bool check = check_signature(messageHash, signature);
        require(check == true, "Fail to verify");

        TrackingAmounts[from][to][false][false] += amount;
        MintableIERC20 to_contract = MintableIERC20(to_contract_add);
        uint256 total = to_contract.balanceOf(address(this));
        if (total < amount){
            to_contract.mint(amount - total);
        }
        bool success = to_contract.transfer(to, amount);
        require(success == true, "Can't unlock");
        emit TransactToken(from, to, amount, false, false);
    }
}