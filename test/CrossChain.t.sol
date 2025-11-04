//SPDX-License-Identifier
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";

import {RebaseToken} from "../src/RebaseToken.sol";

import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";

import {Vault} from "../src/Vault.sol";

import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

contract CrossChainTest is Test {
    uint256 sepoliaFork;
    uint256 arbSepoliaFork;
    CCIPLocalSimulatorFork ccipLocalSimulatorFork;
    address owner =
        address(uint160(uint256(keccak256(abi.encodePacked("owner")))));
    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia");

        arbSepoliaFork = vm.createFork("arb-sepolia");

        RebaseToken sepoliaToken;
        RebaseToken arbSepoliaToken;
        RebaseTokenPool sepoliaPool;
        RebaseTokenPool arbSepoliaPool;
        vm.selectFork(sepoliaFork);
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        vm.selectFork(arbSepoliaFork);
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        Vault vault;

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();

        vm.makePersistent(address(ccipLocalSimulatorFork));

        vm.startPrank(owner);

        sepoliaToken = new RebaseToken();

        vault = new Vault(IRebaseToken(address(sepoliaToken)));

        vm.stopPrank();

        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);

        arbSepoliaToken = new RebaseToken();

        vm.selectFork(sepoliaFork); // Ensure correct fork is selected
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)), // Cast token via address
            new address[](0), // Empty allowlist
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );

        // Inside setup(), after getting arbSepoliaNetworkDetails
        vm.selectFork(arbSepoliaFork); // Ensure correct fork is selected
        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)), // Cast token via address
            new address[](0), // Empty allowlist
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );

        vm.stopPrank();

        vm.selectFork(sepoliaFork);
        vm.startPrank(owner); // Assuming 'owner' is the deployer and owner of sepoliaToken
        sepoliaToken.grantMintAndBurnRole(address(vault));
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));
        vm.stopPrank();

        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner); // Assuming 'owner' is the deployer and owner of arbSepoliaToken
        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool));
        vm.stopPrank();

        // On Sepolia fork
        vm.selectFork(sepoliaFork);
        vm.startPrank(owner);
        RegistryModuleOwnerCustom(
            sepoliaNetworkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(sepoliaToken));
        vm.stopPrank();

        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);
        RegistryModuleOwnerCustom(
            arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(arbSepoliaToken));
        vm.stopPrank();

        vm.selectFork(sepoliaFork);
        vm.startPrank(owner);
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(sepoliaToken));
        vm.stopPrank();

        // On Arbitrum Sepolia fork
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(arbSepoliaToken));
        vm.stopPrank();

        // On Sepolia fork
        vm.selectFork(sepoliaFork);
        vm.startPrank(owner);
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(sepoliaToken), address(sepoliaPool));
        vm.stopPrank();

        // On Arbitrum Sepolia fork
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(arbSepoliaToken), address(arbSepoliaPool));
        vm.stopPrank();
    }
}
