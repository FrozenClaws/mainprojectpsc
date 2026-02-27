// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Storage.sol";
import "./Roles.sol";

contract BatchTransferManager is Storage, Roles {

    error NotOwner();
    error NotApproved();
    error Insufficient();
    error InvalidRoute();

    event BatchCreated(uint64 id);
    event BatchTransferred(uint64 id,address to);

    function createBatch(
        uint64 productId,
        uint96 qty,
        uint32 mfg,
        uint32 exp
    ) external onlyRole(MANUFACTURER){

        Product memory p = products[productId];

        if(!p.approved) revert NotApproved();
        if(p.manufacturer != msg.sender) revert NotOwner();

        unchecked{ batchCounter++; }

        batches[batchCounter] = Batch(
            qty,
            qty,
            mfg,
            exp,
            msg.sender,
            productId
        );

        emit BatchCreated(batchCounter);
    }

    function transferBatch(
        uint64 id,
        address to,
        uint96 qty,
        uint96 price
    ) external {

        Batch storage b = batches[id];

        if(b.owner != msg.sender) revert NotOwner();
        if(b.remaining < qty) revert Insufficient();

        if(hasRole(MANUFACTURER,msg.sender) && !hasRole(DISTRIBUTOR,to))
            revert InvalidRoute();

        if(hasRole(DISTRIBUTOR,msg.sender) && !hasRole(WHOLESALER,to))
            revert InvalidRoute();

        if(hasRole(WHOLESALER,msg.sender) && !hasRole(PHARMACY,to))
            revert InvalidRoute();

        b.remaining -= qty;
        b.owner = to;

        history[id].push(
            Distribution(
                msg.sender,
                to,
                qty,
                price,
                uint32(block.timestamp)
            )
        );

        emit BatchTransferred(id,to);
    }
}