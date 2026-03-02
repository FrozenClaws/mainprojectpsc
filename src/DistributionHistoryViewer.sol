// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStakeholderRegistry {
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IBatchDistribution {

    function stakeholderDistributionIds(uint256 batchId, address holder)
        external view returns (uint256);

    function distributions(uint256 id)
        external
        view
        returns (
            uint256 id_,
            uint256 batchId,
            address from,
            address to,
            uint256 quantity,
            uint256 price,
            string memory billingIPFS,
            uint256 remaining,
            uint256 parentId
        );
}

contract ProductVerificationAndAlert {

    bytes32 public constant REGULATOR = keccak256("ADMIN");
    bytes32 public constant CONSUMER = keccak256("CONSUMER");

    IStakeholderRegistry public stakeholders;
    IBatchDistribution public batches;

    constructor(address stakeholderAddr, address batchAddr) {
        stakeholders = IStakeholderRegistry(stakeholderAddr);
        batches = IBatchDistribution(batchAddr);
    }

    // =====================================================
    // DISTRIBUTION HISTORY STRUCT
    // =====================================================

    struct DistributionRecord {
        uint256 id;
        address from;
        address to;
        uint256 quantity;
        uint256 price;
        string billingIPFS;
    }

    // =====================================================
    // SUSPICION ALERT STRUCT
    // =====================================================

    struct Alert {
        uint256 id;
        uint256 batchId;
        address reporter;
        string reason;
        uint256 timestamp;
        bool resolved;
        string resolution;
    }

    uint256 private alertCounter;

    mapping(uint256 => Alert) public alerts;
    mapping(uint256 => uint256[]) public batchAlerts;

    // =====================================================
    // EVENTS
    // =====================================================

    event SuspicionRaised(uint256 alertId, uint256 batchId, address reporter);
    event AlertResolved(uint256 alertId, string resolution);

    // =====================================================
    // GET DISTRIBUTION HISTORY  (Algorithm 5)
    // =====================================================

    function getDistributionHistory(
        uint256 batchId,
        address stakeholder
    )
        external
        view
        returns (DistributionRecord[] memory)
    {
        uint256 distId =
            batches.stakeholderDistributionIds(batchId, stakeholder);

        require(distId != 0, "No distribution history");

        uint256 tempId = distId;
        uint256 count;

        // count length
        while (tempId != 0) {
            (, , , , , , , , uint256 parent) =
                batches.distributions(tempId);
            tempId = parent;
            count++;
        }

        DistributionRecord[] memory history =
            new DistributionRecord[](count);

        tempId = distId;
        uint256 index;

        // populate array
        while (tempId != 0) {

            (
                uint256 id_,
                ,
                address from,
                address to,
                uint256 qty,
                uint256 price,
                string memory bill,
                ,
                uint256 parent
            ) = batches.distributions(tempId);

            history[index++] =
                DistributionRecord(id_, from, to, qty, price, bill);

            tempId = parent;
        }

        // reverse array
        for (uint256 i = 0; i < count / 2; i++) {
            DistributionRecord memory tmp = history[i];
            history[i] = history[count - 1 - i];
            history[count - 1 - i] = tmp;
        }

        return history;
    }

    // =====================================================
    // RAISE SUSPICION ALERT
    // =====================================================

    function raiseAlert(uint256 batchId, string calldata reason) external {

        require(
            stakeholders.hasRole(CONSUMER, msg.sender) ||
            stakeholders.hasRole(REGULATOR, msg.sender),
            "Unauthorized"
        );

        uint256 id = alertCounter++;

        alerts[id] = Alert({
            id: id,
            batchId: batchId,
            reporter: msg.sender,
            reason: reason,
            timestamp: block.timestamp,
            resolved: false,
            resolution: ""
        });

        batchAlerts[batchId].push(id);

        emit SuspicionRaised(id, batchId, msg.sender);
    }

    // =====================================================
    // REVIEW + RESOLVE ALERT
    // =====================================================

    function resolveAlert(uint256 alertId, string calldata resolution)
        external
    {
        require(
            stakeholders.hasRole(REGULATOR, msg.sender),
            "Only regulator"
        );

        Alert storage a = alerts[alertId];
        require(!a.resolved, "Already resolved");

        a.resolved = true;
        a.resolution = resolution;

        emit AlertResolved(alertId, resolution);
    }

    // =====================================================
    // VIEW ALERTS
    // =====================================================

    function getBatchAlerts(uint256 batchId)
        external
        view
        returns (uint256[] memory)
    {
        return batchAlerts[batchId];
    }

    function getAlert(uint256 id)
        external
        view
        returns (Alert memory)
    {
        return alerts[id];
    }
}