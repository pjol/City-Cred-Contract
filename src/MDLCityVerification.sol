// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISP1Verifier} from "@sp1-contracts/ISP1Verifier.sol";


contract MDLCityVerification {

    address public immutable verifier;
    bytes32 public immutable mdlCityProgramVKey;
    mapping(address => uint256[]) public ids;
    mapping(uint256 => Credential) public credentials;


    struct Credential {
        address account;
        string city;
        uint256 issuedAt;
        bool locked;
        uint256 lockedAt;
    }

    struct PublicValues {
        uint256 id;
        uint256 issuedAt;
        string city;
    }


    constructor(address _verifier, bytes32 _mdlCityProgramVKey) {
        verifier = _verifier;
        mdlCityProgramVKey = _mdlCityProgramVKey;
    }


    function updateCredential(bytes calldata _publicValues, bytes calldata _proofBytes, address newAccount)
        public
    {
        PublicValues memory v = abi.decode(_publicValues, (PublicValues));

        if(block.timestamp > credentials[v.id].lockedAt + 26 weeks) {
            credentials[v.id].locked = false;
        }

        require(!credentials[v.id].locked || msg.sender == credentials[v.id].account,
            "Credential locked, unlock or call this function with the holder account to update.");
        require(block.timestamp >= v.issuedAt,
            "Block somehow older than the credential?");
        require(block.timestamp < v.issuedAt + 10 minutes,
            "Credential must be issued less than 10 minutes ago.");
        require(block.timestamp > credentials[v.id].issuedAt + 3 hours,
            "Credential reassignment heavily rate limited, try again in 3 hours.");



        ISP1Verifier(verifier).verifyProof(mdlCityProgramVKey, _publicValues, _proofBytes);


        if(credentials[v.id].account != newAccount) {
            removeAccountCredential(credentials[v.id].account, v.id);
            ids[newAccount].push(v.id);
        }

        credentials[v.id].account = newAccount;
        credentials[v.id].issuedAt = v.issuedAt;
        credentials[v.id].city = v.city;
    }


    function lockCredential(bytes calldata _publicValues, bytes calldata _proofBytes)
        public
    {
        PublicValues memory v = abi.decode(_publicValues, (PublicValues));


        require(credentials[v.id].account == msg.sender,
            "Credential can only be locked by its holder.");
        require(credentials[v.id].issuedAt != v.issuedAt,
            "Locking proof must be issued separately from updating proof.");
        require(block.timestamp < credentials[v.id].issuedAt + 1 hours,
            "Credential must be locked within an hour of updating.");
        require(equal(credentials[v.id].city, v.city),
            "Not sure how that happened.");
        require(block.timestamp < v.issuedAt + 10 minutes,
            "Credential must be issued less than 10 minutes ago.");
        require(block.timestamp >= v.issuedAt,
            "Block somehow older than the credential?");

        ISP1Verifier(verifier).verifyProof(mdlCityProgramVKey, _publicValues, _proofBytes);

        credentials[v.id].locked = true;
        credentials[v.id].lockedAt = block.timestamp;
    }

    function unlockCredential(uint256 id)
        public
    {
        require(credentials[id].account == msg.sender,
            "Credential can only be unlocked by its owner.");
        credentials[id].locked = false;
        credentials[id].lockedAt = 0;
    }



    function removeCredential(uint256 id)
        public
    {
        require(credentials[id].account == msg.sender);
        removeAccountCredential(msg.sender, id);
        credentials[id].account = address(0);
        credentials[id].city = "";
        credentials[id].issuedAt = 0;
        credentials[id].locked = false;
        credentials[id].lockedAt = 0;
    }


    function getAccountCredentials(address _account, uint32 _page)
        public
        view
        returns (Credential[] memory)
    {
        Credential[] memory creds = new Credential[](10);
        for(uint256 i = 0; i < 10; i++) {
            uint256 id = ids[_account][i + (_page * 10)];
            creds[i] = credentials[id];
        }
        return creds;
    }


    function readIds(address account)
        public
        view
        returns(uint256[] memory)
    {
        return ids[account];
    }

    function balanceOf(address account)
        public
        view
        returns(uint256)
    {
        return ids[account].length;
    }


    function ownerOf(uint256 id)
        public
        view
        returns(address)
    {
        return credentials[id].account;
    }

    function getCredential(uint256 id)
        public
        view
        returns(Credential memory)
    {
        return credentials[id];
    }


    function removeAccountCredential(address account, uint256 id)
        internal
    {
        uint256 index;
        bool found = false;

        for(uint256 i = 0; i < ids[account].length; i++) {
            if(ids[account][i] == id) {
                index = i;
                found = true;
                break;
            }
        }

        if(!found) {
            return;
        }

        ids[account][index] = ids[account][ids[account].length - 1];
        ids[account].pop();
    }

    function decodeIntoPublicValues(bytes calldata _publicValues)
        public
        pure
        returns(PublicValues memory)
    {
        PublicValues memory v = abi.decode(_publicValues, (PublicValues));
        return v;
    }

    function equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
