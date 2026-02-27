// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Storage.sol";
import "./Roles.sol";

contract ProductRegistry is Storage, Roles {

    error NotApproved();

    event ProductQueued(uint64 id);
    event ProductApproved(uint64 id);

    function registerProduct(bytes32 meta)
        external
        onlyRole(MANUFACTURER)
    {
        if(!stakeholders[msg.sender].approved)
            revert NotApproved();

        unchecked{ productCounter++; }

        products[productCounter] = Product(
            msg.sender,
            meta,
            false
        );

        emit ProductQueued(productCounter);
    }

    function approveProduct(uint64 id)
        external
        onlyRole(REGULATOR)
    {
        products[id].approved = true;
        emit ProductApproved(id);
    }
}