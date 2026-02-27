// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract Roles is AccessControl {

    bytes32 public constant MANUFACTURER = keccak256("MANUFACTURER");
    bytes32 public constant DISTRIBUTOR = keccak256("DISTRIBUTOR");
    bytes32 public constant WHOLESALER = keccak256("WHOLESALER");
    bytes32 public constant PHARMACY = keccak256("PHARMACY");
    bytes32 public constant REGULATOR = keccak256("REGULATOR");

    constructor(){
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REGULATOR, msg.sender);
    }
}