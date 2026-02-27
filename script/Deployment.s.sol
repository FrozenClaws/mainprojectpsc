// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {StakeholderRegistry} from "../src/StakeholderRegistry.sol";
import {ProductRegistry} from "../src/ProductRegistry.sol";
import {BatchTransferManager} from "../src/BatchTransferManager.sol";
import {ConsumerSalesManager} from "../src/ConsumerSalesManager.sol";
import {DistributionHistoryViewer} from "../src/DistributionHistoryViewer.sol";

contract DeployAll is Script {

    function run() external {

        vm.startBroadcast();

        new StakeholderRegistry();
        new ProductRegistry();
        new BatchTransferManager();
        new ConsumerSalesManager();
        new DistributionHistoryViewer();

        vm.stopBroadcast();
    }
}