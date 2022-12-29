// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


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
    //From_address => To_address => isNative => Uint256
    mapping (address => mapping(address => mapping(bool => uint256))) public max_approved;
    
    
    event TransactToken(address indexed from, address indexed to, uint256 indexed amount, bool is_native, bool is_lock);
    // event ReceiveNative(address indexed from, uint256 amount);
    // event TransferNative(address indexed to, uint256 amount);
    // event LockToken(address indexed from, address indexed from_contract_add, uint256 amount);
    // event UnlockToken(address indexed from, address indexed from_contract_add, uint256 amount);

    constructor(address[] memory _super_admins) payable {
        for (uint i=0; i < _super_admins.length; i++){
            super_admins[_super_admins[i]] = true;
        }
        
    }

    modifier admin_approved(address from, uint256 amount, bool is_native){
        require(amount <= max_approved[from][msg.sender][is_native], "Higher amount than available amount");
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

    modifier validate_approval_request(address[] memory froms, address[] memory tos, uint256[] memory amounts, bool[] memory is_natives){
        require(froms.length == tos.length, "Froms must have the same length as tos");
        require(tos.length == amounts.length, "Tos must have the same length as amounts");
        require(amounts.length == is_natives.length, "Amounts must have the same length as is_natives");
        _;
    }


    function change_admins(address acc, bool allow) public only_super_admin{
        admins[acc] = allow;
    }

    //Set admin's approval for unlock
    function set_approvals(address[] memory froms, address[] memory tos, uint256[] memory amounts, bool[] memory is_natives) public only_admin validate_approval_request(froms, tos, amounts, is_natives){
        _set_approvals(froms, tos, amounts, is_natives);
    }

    function increase_approvals(address[] memory froms, address[] memory tos, uint256[] memory amounts, bool[] memory is_natives) public only_admin validate_approval_request(froms, tos, amounts, is_natives){
        for (uint32 i = 0; i < amounts.length; i++){
            amounts[i] += max_approved[froms[i]][tos[i]][is_natives[i]];
        }
        _set_approvals(froms, tos, amounts, is_natives);
    }

    function decrease_approvals(address[] memory froms, address[] memory tos, uint256[] memory amounts, bool[] memory is_natives) public only_admin validate_approval_request(froms, tos, amounts, is_natives){
        for (uint32 i = 0; i < amounts.length; i++){
            amounts[i] = max_approved[froms[i]][tos[i]][is_natives[i]] - amounts[i];
        }
        _set_approvals(froms, tos, amounts, is_natives);
    }

    function _set_approvals(address[] memory froms, address[] memory tos, uint256[] memory amounts, bool[] memory is_natives) private {
        for (uint256 i = 0; i < tos.length; i++){
            max_approved[froms[i]][tos[i]][is_natives[i]] = amounts[i];
        }
    }


    //Receiver
    function receive_native(address to) public payable {
        require(msg.value > 0, "Transfer zero");
        emit TransactToken(msg.sender, to, msg.value, true, true);
    }


    //Transfer Native
    function transfer_native(address from, uint256 amount) public payable admin_approved(from, amount, true){
        require(amount <= address(this).balance);
        max_approved[from][msg.sender][true] -= amount;
        (bool sent, ) = (msg.sender).call{value: amount}("");
        require(sent == true, "Fail to transfer");
        emit TransactToken(from, msg.sender, amount, false, false);
    }


    //Lock, require APPROVAL
    function lock(address from_contract_add, uint256 amount, address to) public {
        IERC20 from_contract = IERC20(from_contract_add);
        bool success = from_contract.transferFrom(msg.sender, address(this), amount);
        require(success == true, "Can't lock");
        emit TransactToken(msg.sender, to, amount, false, true);
    }

    //Need to make Bridge an admin in ERC20 contract for minting
    //Unlock
    function unlock(address from, address to_contract_add, uint256 amount) public admin_approved(from, amount, false){
        MintableIERC20 to_contract = MintableIERC20(to_contract_add);
        address to = msg.sender;
        uint256 total = to_contract.balanceOf(address(this));
        if (total < amount){
            to_contract.mint(amount - total);
        }
        max_approved[from][to][false] -= amount;
        bool success = to_contract.transfer(to, amount);
        require(success == true, "Can't unlock");
        emit TransactToken(from, to, amount, false, false);
    }
}