// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MDLCityVerification} from "../src/MDLCityVerification.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {SP1VerifierGateway} from "@sp1-contracts/SP1VerifierGateway.sol";

/// A fixture that can be used to test the verification of SP1 zkVM proofs inside Solidity.
struct SP1ProofFixtureJson {
    bytes proof;
    bytes public_values;
    bytes32 vkey;
}

uint256 constant fixture1timestamp = 1728341932;
uint256 constant fixture2timestamp = 1728342166;


contract MDLCityVerificationTest is Test {
    using stdJson for string;

    address verifier;
    MDLCityVerification public credIssuer;

    function loadFixture(string memory fixture) public view returns (SP1ProofFixtureJson memory) {

        string memory root = vm.projectRoot();
        string memory fixtureName = string.concat(fixture, ".json");
        string memory relativePath = string.concat("/src/example_fixtures/", fixtureName);
        string memory path = string.concat(root, relativePath);
        string memory json = vm.readFile(path);
        bytes memory jsonBytes = json.parseRaw(".");
        return abi.decode(jsonBytes, (SP1ProofFixtureJson));
    }


    function setUp() public {
        SP1ProofFixtureJson memory fixture = loadFixture("fixture1");

        verifier = address(new SP1VerifierGateway(address(1)));
        credIssuer = new MDLCityVerification(verifier, fixture.vkey);
    }


    function test_UpdateCredential() public {
        SP1ProofFixtureJson memory fixture = loadFixture("fixture2");

        vm.mockCall(verifier, abi.encodeWithSelector(SP1VerifierGateway.verifyProof.selector), abi.encode(true));
        vm.warp(fixture2timestamp + 1 minutes);


        MDLCityVerification.PublicValues memory v = credIssuer.decodeIntoPublicValues(fixture.public_values);

        console.log("id:", v.id);
        console.log("iat:", v.issuedAt);
        console.log("city:", v.city);

        try credIssuer.updateCredential(fixture.public_values, fixture.proof, address(1)) {
            console.log("Updated");
        } catch Error(string memory reason) {
            console.log(reason);
            revert(reason);
        }

        assert(credIssuer.getCredential(v.id).account == address(1));
        assert(equal(credIssuer.getCredential(v.id).city, v.city));
        assert(credIssuer.getCredential(v.id).issuedAt == v.issuedAt);
    }


    function testFail_UpdateCredentialExpired() public {
        SP1ProofFixtureJson memory fixture = loadFixture("fixture1");

        vm.mockCall(verifier, abi.encodeWithSelector(SP1VerifierGateway.verifyProof.selector), abi.encode(true));
        vm.warp(fixture1timestamp + 1 hours);

        try credIssuer.updateCredential(fixture.public_values, fixture.proof, address(1)) {
            console.log("Updated");
        } catch Error(string memory reason) {
            console.log(reason);
            revert(reason);
        }
    }


    function testFail_UpdateCredentialRateLimited() public {
        SP1ProofFixtureJson memory fixture = loadFixture("fixture1");

        vm.mockCall(verifier, abi.encodeWithSelector(SP1VerifierGateway.verifyProof.selector), abi.encode(true));
        vm.warp(fixture1timestamp + 1 minutes);

        credIssuer.updateCredential(fixture.public_values, fixture.proof, address(1));

        vm.warp(fixture1timestamp + 2 minutes);

        try credIssuer.updateCredential(fixture.public_values, fixture.proof, address(1)) {
            console.log("Updated");
        } catch Error(string memory reason) {
            console.log(reason);
            revert(reason);
        }
    }


    function test_LockCredential() public {
        SP1ProofFixtureJson memory fixture1 = loadFixture("fixture1");
        SP1ProofFixtureJson memory fixture2 = loadFixture("fixture2");

        vm.mockCall(verifier, abi.encodeWithSelector(SP1VerifierGateway.verifyProof.selector), abi.encode(true));

        vm.warp(fixture1timestamp + 1 minutes);

        credIssuer.updateCredential(fixture1.public_values, fixture1.proof, address(1));

        vm.warp(fixture2timestamp + 1 minutes);

        vm.prank(address(1));

        try credIssuer.lockCredential(fixture2.public_values, fixture2.proof) {
            console.log("Locked");
        } catch Error(string memory reason) {
            console.log(reason);
            revert(reason);
        }

        MDLCityVerification.PublicValues memory v = credIssuer.decodeIntoPublicValues(fixture1.public_values);

        assert(credIssuer.getCredential(v.id).locked == true);
    }


    function testFail_LockCredentialBadSender() public {
        SP1ProofFixtureJson memory fixture1 = loadFixture("fixture1");
        SP1ProofFixtureJson memory fixture2 = loadFixture("fixture2");

        vm.mockCall(verifier, abi.encodeWithSelector(SP1VerifierGateway.verifyProof.selector), abi.encode(true));

        vm.warp(fixture1timestamp + 1 minutes);

        credIssuer.updateCredential(fixture1.public_values, fixture1.proof, address(1));

        vm.warp(fixture2timestamp + 1 minutes);

        vm.prank(address(0));

        try credIssuer.lockCredential(fixture2.public_values, fixture2.proof) {
            console.log("Locked");
        } catch Error(string memory reason) {
            console.log(reason);
            revert(reason);
        }
    }

    function testFail_LockCredentialExpired() public {
        SP1ProofFixtureJson memory fixture1 = loadFixture("fixture1");
        SP1ProofFixtureJson memory fixture2 = loadFixture("fixture2");

        vm.mockCall(verifier, abi.encodeWithSelector(SP1VerifierGateway.verifyProof.selector), abi.encode(true));

        vm.warp(fixture1timestamp + 1 minutes);

        credIssuer.updateCredential(fixture1.public_values, fixture1.proof, address(1));

        vm.warp(fixture1timestamp + 2 hours);

        vm.prank(address(1));

        try credIssuer.lockCredential(fixture2.public_values, fixture2.proof) {
            console.log("Locked");
        } catch Error(string memory reason) {
            console.log(reason);
            revert(reason);
        }
    }


    function testFail_LockCredentialDuplicate() public {
        SP1ProofFixtureJson memory fixture1 = loadFixture("fixture1");

        vm.mockCall(verifier, abi.encodeWithSelector(SP1VerifierGateway.verifyProof.selector), abi.encode(true));

        vm.warp(fixture1timestamp + 1 minutes);

        credIssuer.updateCredential(fixture1.public_values, fixture1.proof, address(1));

        vm.warp(fixture1timestamp + 2 minutes);

        vm.prank(address(1));

        try credIssuer.lockCredential(fixture1.public_values, fixture1.proof) {
            console.log("Locked");
        } catch Error(string memory reason) {
            console.log(reason);
            revert(reason);
        }
    }

    function test_UnlockCredential() public {
        SP1ProofFixtureJson memory fixture1 = loadFixture("fixture1");
        SP1ProofFixtureJson memory fixture2 = loadFixture("fixture2");

        vm.mockCall(verifier, abi.encodeWithSelector(SP1VerifierGateway.verifyProof.selector), abi.encode(true));

        vm.warp(fixture1timestamp + 1 minutes);

        credIssuer.updateCredential(fixture1.public_values, fixture1.proof, address(1));

        vm.warp(fixture2timestamp + 1 minutes);

        vm.prank(address(1));

        credIssuer.lockCredential(fixture2.public_values, fixture2.proof);

        MDLCityVerification.PublicValues memory v = credIssuer.decodeIntoPublicValues(fixture1.public_values);

        vm.prank(address(1));

        try credIssuer.unlockCredential(v.id) {
            console.log("Unlocked");
        } catch Error(string memory reason) {
            console.log(reason);
            revert(reason);
        }

        assert(credIssuer.getCredential(v.id).locked == false);
    }


    function testFail_UnlockCredential() public {
        SP1ProofFixtureJson memory fixture1 = loadFixture("fixture1");
        SP1ProofFixtureJson memory fixture2 = loadFixture("fixture2");

        vm.mockCall(verifier, abi.encodeWithSelector(SP1VerifierGateway.verifyProof.selector), abi.encode(true));

        vm.warp(fixture1timestamp + 1 minutes);

        credIssuer.updateCredential(fixture1.public_values, fixture1.proof, address(1));

        vm.warp(fixture2timestamp + 1 minutes);

        vm.prank(address(1));

        credIssuer.lockCredential(fixture2.public_values, fixture2.proof);

        MDLCityVerification.PublicValues memory v = credIssuer.decodeIntoPublicValues(fixture1.public_values);

        vm.prank(address(0));

        try credIssuer.unlockCredential(v.id) {
            console.log("Unlocked");
        } catch Error(string memory reason) {
            console.log(reason);
            revert(reason);
        }
    }


    function equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
