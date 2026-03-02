// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStakeholderRegistry {
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IProductRegistry {
    function getApprovedProduct(uint256 id)
        external
        view
        returns (
            uint256,
            string memory,
            string memory,
            string memory,
            string memory,
            string memory,
            address,
            bool,
            bool
        );
}

contract BatchDistribution {

    // --------------------------------------------------
    // ROLES
    // --------------------------------------------------

    bytes32 public constant MANUFACTURER = keccak256("MANUFACTURER");
    bytes32 public constant DISTRIBUTOR = keccak256("DISTRIBUTOR");
    bytes32 public constant WHOLESALER = keccak256("WHOLESALER");
    bytes32 public constant PHARMACY = keccak256("PHARMACY");

    IStakeholderRegistry public stakeholders;
    IProductRegistry public products;

    constructor(address stakeholderAddr, address productAddr) {
        stakeholders = IStakeholderRegistry(stakeholderAddr);
        products = IProductRegistry(productAddr);
    }

    // --------------------------------------------------
    // STRUCTS
    // --------------------------------------------------

    struct Batch {
        uint256 batchId;
        uint256 productId;
        uint256 quantity;
        uint256 remainingQuantity;
        string metadataURI;
        uint256 productionDate;
        uint256 expiryDate;
        uint256 rootDistributionId;
        address manufacturer;
        bool exists;
    }

    struct Distribution {
        uint256 id;
        uint256 batchId;
        address from;
        address to;
        uint256 quantity;
        uint256 price;
        string billingIPFS;
        uint256 remainingQuantity;
        uint256 parentId;
        uint256[] childIds;
    }

    // --------------------------------------------------
    // STORAGE
    // --------------------------------------------------

    uint256 private batchCounter;
    uint256 private distributionCounter;

    mapping(uint256 => Batch) public batches;
    mapping(uint256 => Distribution) public distributions;

    // stakeholder → batch → distributionId
    mapping(uint256 => mapping(address => uint256))
        public stakeholderDistributionIds;

    // --------------------------------------------------
    // EVENTS
    // --------------------------------------------------

    event BatchCreated(
        uint256 batchId,
        uint256 productId,
        address manufacturer,
        uint256 quantity
    );

    event BatchTransferred(
        uint256 batchId,
        uint256 distributionId,
        address from,
        address to,
        uint256 quantity,
        uint256 price,
        string billingURI
    );

    // --------------------------------------------------
    // MODIFIERS
    // --------------------------------------------------

    modifier onlyRole(bytes32 role) {
        require(stakeholders.hasRole(role, msg.sender), "Invalid role");
        _;
    }

    modifier batchExists(uint256 id) {
        require(batches[id].exists, "Batch not found");
        _;
    }

    // --------------------------------------------------
    // CREATE BATCH
    // --------------------------------------------------

    function createBatch(
        uint256 productId,
        uint256 quantity,
        string memory metadataURI,
        uint256 productionDate,
        uint256 expiryDate
    ) external onlyRole(MANUFACTURER) {

        // verify product exists + approved
        (, , , , , , , bool approved, bool exists) =
            products.getApprovedProduct(productId);

        require(exists && approved, "Product not approved");

        uint256 batchId = batchCounter++;

        batches[batchId] = Batch({
            batchId: batchId,
            productId: productId,
            quantity: quantity,
            remainingQuantity: quantity,
            metadataURI: metadataURI,
            productionDate: productionDate,
            expiryDate: expiryDate,
            rootDistributionId: 0,
            manufacturer: msg.sender,
            exists: true
        });

        // root distribution node
        uint256 rootId = distributionCounter++;

        distributions[rootId] = Distribution({
            id: rootId,
            batchId: batchId,
            from: address(0),
            to: msg.sender,
            quantity: quantity,
            price: 0,
            billingIPFS: "",
            remainingQuantity: quantity,
            parentId: 0,
            childIds: new uint256[](0)
        });

        batches[batchId].rootDistributionId = rootId;
        stakeholderDistributionIds[batchId][msg.sender] = rootId;

        emit BatchCreated(batchId, productId, msg.sender, quantity);
    }

    // --------------------------------------------------
    // TRANSFER BATCH  (Algorithm 3)
    // --------------------------------------------------

    function transferBatch(
        uint256 batchId,
        address to,
        uint256 quantity,
        uint256 price,
        string memory billingIPFS
    ) external batchExists(batchId) {

        require(
            stakeholders.hasRole(MANUFACTURER, to) ||
            stakeholders.hasRole(DISTRIBUTOR, to) ||
            stakeholders.hasRole(WHOLESALER, to) ||
            stakeholders.hasRole(PHARMACY, to),
            "Receiver invalid"
        );

        uint256 parentId = stakeholderDistributionIds[batchId][msg.sender];
        require(parentId != 0 || msg.sender == batches[batchId].manufacturer,
            "Not holder");

        if (msg.sender == batches[batchId].manufacturer) {
            require(stakeholders.hasRole(DISTRIBUTOR, to), "Manufacturer -> Distributor only");
            parentId = batches[batchId].rootDistributionId;
        }
        else if (stakeholders.hasRole(DISTRIBUTOR, msg.sender)) {
            require(stakeholders.hasRole(WHOLESALER, to), "Distributor -> Wholesaler only");
        }
        else if (stakeholders.hasRole(WHOLESALER, msg.sender)) {
            require(stakeholders.hasRole(PHARMACY, to), "Wholesaler -> Pharmacy only");
        }

        Distribution storage parent = distributions[parentId];

        require(quantity <= parent.remainingQuantity, "Insufficient qty");

        uint256 distributionId = distributionCounter++;

        distributions[distributionId] = Distribution({
            id: distributionId,
            batchId: batchId,
            from: msg.sender,
            to: to,
            quantity: quantity,
            price: price,
            billingIPFS: billingIPFS,
            remainingQuantity: quantity,
            parentId: parentId,
            childIds: new uint256[](0)
        });

        parent.remainingQuantity -= quantity;
        parent.childIds.push(distributionId);

        stakeholderDistributionIds[batchId][to] = distributionId;

        emit BatchTransferred(
            batchId,
            distributionId,
            msg.sender,
            to,
            quantity,
            price,
            billingIPFS
        );
    }

    function reduceDistributionQty(uint256 id, 
                                   uint256 amount) external {
        require(distributions[id].remainingQuantity >= amount, "Too much");
        distributions[id].remainingQuantity -= amount;
    }

    // --------------------------------------------------
    // VIEW FUNCTIONS
    // --------------------------------------------------

    function getBatch(uint256 id)
        external
        view
        batchExists(id)
        returns (Batch memory)
    {
        return batches[id];
    }

    function getDistribution(uint256 id)
        external
        view
        returns (Distribution memory)
    {
        return distributions[id];
    }

    function getHolderDistribution(uint256 batchId, address holder)
        external
        view
        returns (uint256)
    {
        return stakeholderDistributionIds[batchId][holder];
    }
}