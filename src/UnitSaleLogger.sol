// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStakeholderRegistry {
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IBatchDistribution {

    function stakeholderDistributionIds(uint256 batchId, address holder)
        external view returns (uint256);

    function distributions(uint256 id)
        external view
        returns (
            uint256,
            uint256,
            address,
            address,
            uint256,
            uint256,
            string memory,
            uint256,
            uint256
        );

    function reduceDistributionQty(uint256 id, uint256 amount) external;
}

contract UnitSaleLogger {

    bytes32 public constant PHARMACY = keccak256("PHARMACY");
    bytes32 public constant CONSUMER = keccak256("CONSUMER");

    IStakeholderRegistry public stakeholders;
    IBatchDistribution public batches;

    constructor(address stakeholderAddr, address batchAddr) {
        stakeholders = IStakeholderRegistry(stakeholderAddr);
        batches = IBatchDistribution(batchAddr);
    }

    // --------------------------------------------------
    // STRUCT
    // --------------------------------------------------

    struct UnitSale {
        uint256 saleId;
        uint256 batchId;
        address pharmacy;
        address consumer;
        uint256 quantity;
        uint256 timestamp;
    }

    // --------------------------------------------------
    // STORAGE
    // --------------------------------------------------

    uint256 private saleCounter;

    mapping(uint256 => mapping(uint256 => UnitSale)) public unitSales;
    mapping(uint256 => mapping(address => bool)) public batchConsumers;

    // --------------------------------------------------
    // EVENTS
    // --------------------------------------------------

    event UnitsSold(
        uint256 batchId,
        uint256 saleId,
        address from,
        address to,
        uint256 quantity,
        uint256 timestamp
    );

    // --------------------------------------------------
    // MODIFIER
    // --------------------------------------------------

    modifier onlyPharmacy(address user) {
        require(stakeholders.hasRole(PHARMACY, user), "Not pharmacy");
        _;
    }

    modifier onlyConsumer(address user) {
        require(stakeholders.hasRole(CONSUMER, user), "Not consumer");
        _;
    }

    // --------------------------------------------------
    // SELL FUNCTION  (Algorithm 4)
    // --------------------------------------------------

    function sellUnits(
        uint256 batchId,
        address to,
        uint256 quantity
    ) external {

        // --------------------------------------------------
        // CASE 1 — PHARMACY sells to consumer
        // --------------------------------------------------
        if (stakeholders.hasRole(PHARMACY, msg.sender)) {

            uint256 distId =
                batches.stakeholderDistributionIds(batchId, msg.sender);

            require(distId != 0, "Pharmacy not batch holder");

            (, , , , , , , uint256 remaining,) =
                batches.distributions(distId);

            require(quantity <= remaining, "Insufficient quantity");

            uint256 saleId = saleCounter++;

            unitSales[batchId][saleId] = UnitSale({
                saleId: saleId,
                batchId: batchId,
                pharmacy: msg.sender,
                consumer: to,
                quantity: quantity,
                timestamp: block.timestamp
            });

            batches.reduceDistributionQty(distId, quantity);
            batchConsumers[batchId][to] = true;

            emit UnitsSold(
                batchId,
                saleId,
                msg.sender,
                to,
                quantity,
                block.timestamp
            );
        }

        // --------------------------------------------------
        // CASE 2 — CONSUMER purchases from pharmacy
        // --------------------------------------------------
        else if (stakeholders.hasRole(CONSUMER, msg.sender)) {

            require(
                stakeholders.hasRole(PHARMACY, to),
                "Target not pharmacy"
            );

            uint256 distId =
                batches.stakeholderDistributionIds(batchId, to);

            require(distId != 0, "Pharmacy not holder");

            (, , , , , , , uint256 remaining,) =
                batches.distributions(distId);

            require(quantity <= remaining, "Insufficient stock");

            uint256 saleId = saleCounter++;

            unitSales[batchId][saleId] = UnitSale({
                saleId: saleId,
                batchId: batchId,
                pharmacy: to,
                consumer: msg.sender,
                quantity: quantity,
                timestamp: block.timestamp
            });

            batches.reduceDistributionQty(distId, quantity);
            batchConsumers[batchId][msg.sender] = true;

            emit UnitsSold(
                batchId,
                saleId,
                to,
                msg.sender,
                quantity,
                block.timestamp
            );
        }

        // --------------------------------------------------
        // INVALID CALLER
        // --------------------------------------------------
        else {
            revert("Caller must be pharmacy or consumer");
        }
    }

    // --------------------------------------------------
    // VIEW FUNCTIONS
    // --------------------------------------------------

    function getSale(uint256 batchId, uint256 saleId)
        external
        view
        returns (UnitSale memory)
    {
        return unitSales[batchId][saleId];
    }

    function isConsumerOfBatch(uint256 batchId, address user)
        external
        view
        returns (bool)
    {
        return batchConsumers[batchId][user];
    }
}