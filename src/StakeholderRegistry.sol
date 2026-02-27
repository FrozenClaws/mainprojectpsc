// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Storage.sol";
import "./Roles.sol";

contract StakeholderRegistry is Storage, Roles {

    error AlreadyRegistered();

    event StakeholderQueued(address user);
    event StakeholderApproved(address user);

    function registerStakeholder(
        bytes32 details,
        bytes32 license,
        bytes32 role
    ) external {

        if(stakeholders[msg.sender].details != 0)
            revert AlreadyRegistered();

        stakeholders[msg.sender] = Stakeholder(
            details,
            license,
            false
        );

        _grantRole(role,msg.sender);

        emit StakeholderQueued(msg.sender);
    }

    function approveStakeholder(address user)
        external
        onlyRole(REGULATOR)
    {
        stakeholders[user].approved = true;
        emit StakeholderApproved(user);
    }
}