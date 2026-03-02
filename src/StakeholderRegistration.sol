// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract StakeholderOnboarding is AccessControl {

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant CONSUMER_ROLE = keccak256("CONSUMER");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    struct Stakeholder {
        string name;
        string email;
        bytes32 passwordHash;
        bytes32 role;
        string location;
        string detailsIPFSURL;
        string license;
        bool approved;
        bool exists;
    }

    mapping(address => Stakeholder) public stakeholders;
    mapping(bytes32 => address[]) public stakeholdersByRole;

    address[] public registrationQueue;
    mapping(address => uint256) public registrationQueueIndex;
    mapping(address => bool) public isInRegistrationQueue;

    event StakeholderRegistered(address indexed user, bytes32 role);
    event StakeholderApproved(address indexed user, bytes32 role);
    event StakeholderRejected(address indexed user);
    event StakeholderUpdated(address indexed user);

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Not admin");
        _;
    }

    modifier onlyQueued() {
        require(isInRegistrationQueue[msg.sender], "Not in queue");
        _;
    }

    modifier exists(address user) {
        require(stakeholders[user].exists, "Not registered");
        _;
    }

    // --------------------------------------------------
    // Register Stakeholder  (Algorithm 1)
    // --------------------------------------------------
    function registerStakeholder(
        string memory name,
        string memory email,
        string memory password,
        bytes32 role,
        string memory location,
        string memory detailsIPFSURL,
        string memory license
    ) external {

        require(!stakeholders[msg.sender].exists, "Already registered");
        require(!isInRegistrationQueue[msg.sender], "Already in queue");

        bytes32 hashPassword = keccak256(abi.encodePacked(password));
        bool isApproved = (role == CONSUMER_ROLE);

        stakeholders[msg.sender] = Stakeholder({
            name: name,
            email: email,
            passwordHash: hashPassword,
            role: role,
            location: location,
            detailsIPFSURL: detailsIPFSURL,
            license: license,
            approved: isApproved,
            exists: true
        });

        if (!isApproved) {
            registrationQueue.push(msg.sender);
            registrationQueueIndex[msg.sender] = registrationQueue.length - 1;
            isInRegistrationQueue[msg.sender] = true;
        } else {
            _grantRole(role, msg.sender);
            stakeholdersByRole[role].push(msg.sender);
        }

        emit StakeholderRegistered(msg.sender, role);
    }

    // --------------------------------------------------
    // Update Registration (only if pending)
    // --------------------------------------------------
    function updateRegistration(
        string memory name,
        string memory email,
        string memory location,
        string memory detailsIPFSURL,
        string memory license
    ) external onlyQueued exists(msg.sender) {

        Stakeholder storage s = stakeholders[msg.sender];

        s.name = name;
        s.email = email;
        s.location = location;
        s.detailsIPFSURL = detailsIPFSURL;
        s.license = license;

        emit StakeholderUpdated(msg.sender);
    }

    // --------------------------------------------------
    // Get Stakeholder Details
    // --------------------------------------------------
    function getStakeholder(address user)
        external
        view
        exists(user)
        returns (Stakeholder memory)
    {
        return stakeholders[user];
    }

    // --------------------------------------------------
    // Approve Registration (Admin only)
    // --------------------------------------------------
    function approveStakeholder(address user)
        external
        onlyAdmin
        exists(user)
    {
        require(isInRegistrationQueue[user], "Not pending");

        Stakeholder storage s = stakeholders[user];
        s.approved = true;

        _grantRole(s.role, user);
        stakeholdersByRole[s.role].push(user);

        _removeFromQueue(user);

        emit StakeholderApproved(user, s.role);
    }

    // --------------------------------------------------
    // Reject Registration (Admin only)
    // --------------------------------------------------
    function rejectStakeholder(address user)
        external
        onlyAdmin
        exists(user)
    {
        require(isInRegistrationQueue[user], "Not pending");

        delete stakeholders[user];
        _removeFromQueue(user);

        emit StakeholderRejected(user);
    }

    // --------------------------------------------------
    // Internal Queue Removal (O(1))
    // --------------------------------------------------
    function _removeFromQueue(address user) internal {
        uint256 index = registrationQueueIndex[user];
        uint256 lastIndex = registrationQueue.length - 1;

        if (index != lastIndex) {
            address last = registrationQueue[lastIndex];
            registrationQueue[index] = last;
            registrationQueueIndex[last] = index;
        }

        registrationQueue.pop();
        delete registrationQueueIndex[user];
        isInRegistrationQueue[user] = false;
    }

    // --------------------------------------------------
    // View Queue
    // --------------------------------------------------
    function getRegistrationQueue() external view returns (address[] memory) {
        return registrationQueue;
    }
}