// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStakeholderRegistry {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getStakeholder(address user)
        external
        view
        returns (
            string memory name,
            string memory email,
            bytes32 passwordHash,
            bytes32 role,
            string memory location,
            string memory detailsIPFSURL,
            string memory license,
            bool approved,
            bool exists
        );
}

contract ProductRegistration {

    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER");
    bytes32 public constant REGULATOR_ROLE = keccak256("ADMIN");

    IStakeholderRegistry public stakeholderContract;

    constructor(address stakeholderAddress) {
        stakeholderContract = IStakeholderRegistry(stakeholderAddress);
    }

    // --------------------------------------------------
    // STRUCT
    // --------------------------------------------------

    struct Product {
        uint256 id;
        string name;
        string description;
        string ingredients;
        string photoIPFSURL;
        string certificateIPFSURL;
        address manufacturer;
        bool approved;
        bool exists;
    }

    // --------------------------------------------------
    // STORAGE
    // --------------------------------------------------

    uint256 private registrationIdCounter;

    mapping(uint256 => Product) private products;

    uint256[] public registrationQueue;
    mapping(uint256 => bool) public isRegistrationIdInQueue;
    mapping(uint256 => uint256) private queueIndex;

    uint256[] public approvedProducts;

    // --------------------------------------------------
    // EVENTS
    // --------------------------------------------------

    event ProductRegistered(uint256 indexed id, string name, address manufacturer);
    event ProductApproved(uint256 indexed id);
    event ProductRejected(uint256 indexed id);

    // --------------------------------------------------
    // MODIFIERS
    // --------------------------------------------------

    modifier onlyManufacturer() {
        require(
            stakeholderContract.hasRole(MANUFACTURER_ROLE, msg.sender),
            "Not manufacturer"
        );
        _;
    }

    modifier onlyRegulator() {
        require(
            stakeholderContract.hasRole(REGULATOR_ROLE, msg.sender),
            "Not regulator"
        );
        _;
    }

    modifier exists(uint256 id) {
        require(products[id].exists, "Product does not exist");
        _;
    }

    // --------------------------------------------------
    // REGISTER PRODUCT (Algorithm 2)
    // --------------------------------------------------

    function registerProduct(
        string memory name,
        string memory description,
        string memory ingredients,
        string memory photoIPFSURL,
        string memory certificateIPFSURL
    ) external onlyManufacturer {

        uint256 registrationId = registrationIdCounter;
        registrationIdCounter++;

        products[registrationId] = Product({
            id: registrationId,
            name: name,
            description: description,
            ingredients: ingredients,
            photoIPFSURL: photoIPFSURL,
            certificateIPFSURL: certificateIPFSURL,
            manufacturer: msg.sender,
            approved: false,
            exists: true
        });

        registrationQueue.push(registrationId);
        queueIndex[registrationId] = registrationQueue.length - 1;
        isRegistrationIdInQueue[registrationId] = true;

        emit ProductRegistered(registrationId, name, msg.sender);
    }

    // --------------------------------------------------
    // APPROVE PRODUCT
    // --------------------------------------------------

    function approveProduct(uint256 id)
        external
        onlyRegulator
        exists(id)
    {
        require(isRegistrationIdInQueue[id], "Not pending");

        Product storage p = products[id];
        p.approved = true;

        approvedProducts.push(id);

        _removeFromQueue(id);

        emit ProductApproved(id);
    }

    // --------------------------------------------------
    // REJECT PRODUCT
    // --------------------------------------------------

    function rejectProduct(uint256 id)
        external
        onlyRegulator
        exists(id)
    {
        require(isRegistrationIdInQueue[id], "Not pending");

        delete products[id];

        _removeFromQueue(id);

        emit ProductRejected(id);
    }

    // --------------------------------------------------
    // INTERNAL QUEUE REMOVAL
    // --------------------------------------------------

    function _removeFromQueue(uint256 id) internal {

        uint256 index = queueIndex[id];
        uint256 lastIndex = registrationQueue.length - 1;

        if (index != lastIndex) {
            uint256 lastId = registrationQueue[lastIndex];
            registrationQueue[index] = lastId;
            queueIndex[lastId] = index;
        }

        registrationQueue.pop();

        delete queueIndex[id];
        isRegistrationIdInQueue[id] = false;
    }

    // --------------------------------------------------
    // GET PENDING PRODUCT DETAILS
    // --------------------------------------------------

    function getProductForApproval(uint256 id)
        external
        view
        onlyRegulator
        exists(id)
        returns (Product memory)
    {
        require(isRegistrationIdInQueue[id], "Not pending");
        return products[id];
    }

    // --------------------------------------------------
    // GET APPROVED PRODUCT DETAILS
    // --------------------------------------------------

    function getApprovedProduct(uint256 id)
        external
        view
        exists(id)
        returns (Product memory)
    {
        require(products[id].approved, "Not approved");
        return products[id];
    }

    // --------------------------------------------------
    // GET ALL APPROVED PRODUCTS
    // --------------------------------------------------

    function getAllApprovedProducts()
        external
        view
        returns (uint256[] memory)
    {
        return approvedProducts;
    }

    // --------------------------------------------------
    // VIEW QUEUE
    // --------------------------------------------------

    function getPendingQueue()
        external
        view
        returns (uint256[] memory)
    {
        return registrationQueue;
    }
}