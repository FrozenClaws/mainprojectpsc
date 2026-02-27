// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Storage {

    struct Stakeholder {
        bytes32 details;
        bytes32 license;
        bool approved;
    }

    struct Product {
        address manufacturer;
        bytes32 meta;
        bool approved;
    }

    struct Batch {
        uint96 total;
        uint96 remaining;
        uint32 mfg;
        uint32 exp;
        address owner;
        uint64 productId;
    }

    struct Distribution {
        address from;
        address to;
        uint96 qty;
        uint96 price;
        uint32 time;
    }

    mapping(address => Stakeholder) internal stakeholders;
    mapping(uint64 => Product) internal products;
    mapping(uint64 => Batch) internal batches;
    mapping(uint64 => Distribution[]) internal history;

    uint64 internal productCounter;
    uint64 internal batchCounter;
}