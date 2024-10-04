// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISP1Verifier} from "@sp1-contracts/ISP1Verifier.sol";


contract MDLCityVerification {

    address public verifier;
    bytes32 public mdlCityProgramVKey;
    mapping(address => string[]) public ids;
    mapping(string => Credential) public credentials;


    struct Credential {
        address account;
        string city;
        int64 issuedAt;
        bool locked;
        int64 lockedAt;
    }


    constructor(address _verifier, bytes32 _mdlCityProgramVKey) {
        verifier = _verifier;
        mdlCityProgramVKey = _mdlCityProgramVKey;
    }



    function updateCredential(bytes calldata _publicValues, bytes calldata _proofBytes, address newAccount) public {

        (int64 iat, string memory city, string memory id) = abi.decode(_publicValues, (int64, string, string));

        if(block.timestamp > credentials[id].lockedAt + 26 weeks) {
            credentials[id].locked = false;
        }

        require(!credentials[id].locked || msg.sender != credentials[id].account,
            "Credential locked, unlock or call this function with the holder account to update.");
        require(block.timestamp < iat + 10 minutes,
            "Credential must be issued less than 10 minutes ago.");
        require(block.timestamp > iat,
            "Block somehow older than the credential?");
        require(block.timestamp > credentials[id].issuedAt + 3 hours,
            "Credential reassignment heavily rate limited, try again in 3 hours.");


        ISP1Verifier(verifier).verifyProof(mdlCityProgramVKey, _publicValues, _proofBytes);


        if(credentials[id].account != newAccount) {
            removeAccountCredential(credentials[id].account, id);
            ids[newAccount].push(id);
        }

        credentials[id].account = newAccount;
        credentials[id].issuedAt = iat;
        credentials[id].city = city;
    }


    function lockCredential(bytes calldata _publicValues, bytes calldata _proofBytes)
        public
    {
        (int64 iat, string memory city, string memory id) = abi.decode(_publicValues, (int64, string, string));

        require(credentials[id].account == msg.sender,
            "Credential can only be locked by its holder.");
        require(credentials[id].issuedAt != iat,
            "Locking credential must be issued separately from updating credential.");
        require(credentials[id].city == city,
            "Not sure how that happened.");
        require(block.timestamp < credentials[id].issuedAt + 1 hours,
            "Credential must be locked within an hour of updating.");
        require(block.timestamp < iat + 10 minutes,
            "Credential must be issued less than 10 minutes ago.");
        require(block.timestamp > iat,
            "Block somehow older than the credential?");

        ISP1Verifier(verifier).verifyProof(mdlCityProgramVKey, _publicValues, _proofBytes);

        credentials[id].locked = true;
        credentials[id].lockedAt = block.timestamp;
    }

    function unlockCredential(string calldata id)
        public
    {
        require(credentials[id].account == msg.sender);
        credentials[id].locked = false;
        credentials[id].lockedAt = 0;
    }



    function removeCredential(string calldata id)
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
            string memory id = ids[_account][i + (_page * 10)];
            creds[i] = credentials[id];
        }
        return creds;
    }


    function readIds(address account)
        public
        view
        returns(string[] memory)
    {
        return ids[account];
    }


    function getCredential(string calldata id)
        public
        view
        returns(Credential memory)
    {
        return credentials[id];
    }

    function removeAccountCredential(address account, string memory id)
        private
    {
        uint256 index;
        bool found = false;

        for(uint256 i = 0; i < ids[account].length; i++) {
            string memory accId = ids[account][i];
            if(accId == id) {
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

}
