// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MDLCityVerifier} from "../src/MDLCityVerifier.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {SP1VerifierGateway} from "@sp1-contracts/SP1VerifierGateway.sol";

struct SP1ProofFixtureJson {
    uint256 issued_at;
    string city;
    string id;
    bytes proof;
    bytes public_values;
    bytes32 vkey;
}


contract MDLCityVerifierScript is Script {
    using stdJson for string;

    address verifier;
    MDLCityVerifier public credIssuer;


    function loadFixture(string memory fixture) public view returns (SP1ProofFixtureJson memory) {
        string memory root = vm.projectRoot();
        string memory fixtureName = string.concat(fixture, ".json");
        string memory relativePath = string.concat("/src/fixtures/", fixtureName);
        string memory path = string.concat(root, relativePath);
        string memory json = vm.readFile(path);
        bytes memory jsonBytes = json.parseRaw(".");
        return abi.decode(jsonBytes, (SP1ProofFixtureJson));
    }

    function setUp() public {
    }

    function run() public {
        vm.startBroadcast();

        SP1ProofFixtureJson memory fixture = loadFixture("fixture2");

        verifier = address(new SP1VerifierGateway(address(1)));
        credIssuer = new MDLCityVerifier(verifier, fixture.vkey);

        vm.stopBroadcast();
    }
}
