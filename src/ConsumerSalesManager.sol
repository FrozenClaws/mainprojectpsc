// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Storage.sol";
import "./Roles.sol";

contract ConsumerSalesManager is Storage, Roles {

    error NotOwner();
    error Insufficient();

    event UnitsSold(uint64 batch,address buyer);

    function sell(
        uint64 id,
        address consumer,
        uint96 qty
    ) external onlyRole(PHARMACY){

        Batch storage b = batches[id];

        if(b.owner != msg.sender) revert NotOwner();
        if(b.remaining < qty) revert Insufficient();

        b.remaining -= qty;

        emit UnitsSold(id,consumer);
    }
}