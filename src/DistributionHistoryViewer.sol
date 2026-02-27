// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Storage.sol";

contract DistributionHistoryViewer is Storage {

    function getHistory(uint64 id)
        external
        view
        returns(Distribution[] memory)
    {
        return history[id];
    }
}