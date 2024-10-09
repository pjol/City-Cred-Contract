// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SP1Verifier} from "@sp1-contracts/v2.0.0/SP1VerifierPlonk.sol";
import {ISP1Verifier} from "@sp1-contracts/ISP1Verifier.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MDLCityVerifier is ERC721 {

    address public immutable verifier;
    bytes32 public immutable mdlCityProgramVKey;
    mapping(address owner => uint256[]) private _ownedTokens;
    mapping(uint256 => Credential) private _credentials;


    struct Credential {
        address owner;
        string city;
        uint256 issuedAt;
        bool locked;
        uint256 lockedAt;
    }

    struct PublicValues {
        address owner;
        uint256 id;
        uint256 issuedAt;
        string city;
    }

    error ErrorFunctionDisabled();


    constructor(address _verifier, bytes32 _mdlCityProgramVKey) ERC721("California mDL City Credentials", "mDLC") {
        verifier = _verifier;
        mdlCityProgramVKey = _mdlCityProgramVKey;
    }


    function updateCredential(bytes calldata _publicValues, bytes calldata _proofBytes)
        public
    {
        PublicValues memory v = abi.decode(_publicValues, (PublicValues));

        if(block.timestamp > _credentials[v.id].lockedAt + 26 weeks) {
            _credentials[v.id].locked = false;
        }

        require(!_credentials[v.id].locked || msg.sender == _credentials[v.id].owner,
            "Credential locked, unlock or call this function with the holder owner to update.");
        require(block.timestamp >= v.issuedAt,
            "Block somehow older than the credential?");
        require(block.timestamp < v.issuedAt + 10 minutes,
            "Credential must be issued less than 10 minutes ago.");
        require(block.timestamp > _credentials[v.id].issuedAt + 3 hours,
            "Credential reassignment heavily rate limited, try again in 3 hours.");



        ISP1Verifier(verifier).verifyProof(mdlCityProgramVKey, _publicValues, _proofBytes);


        if(_credentials[v.id].owner != v.owner) {
            _removeCredential(_credentials[v.id].owner, v.id);
            _ownedTokens[v.owner].push(v.id);
            emit Transfer(_credentials[v.id].owner, v.owner, v.id);
            _credentials[v.id].owner = v.owner;
        }

        _credentials[v.id].issuedAt = v.issuedAt;
        _credentials[v.id].city = v.city;
    }


    function lockCredential(bytes calldata _publicValues, bytes calldata _proofBytes)
        public
    {
        PublicValues memory v = abi.decode(_publicValues, (PublicValues));


        require(_credentials[v.id].owner == msg.sender,
            "Credential can only be locked by its holder.");
        require(_credentials[v.id].owner == v.owner,
            "Proof owner must match current credential owner.");
        require(_credentials[v.id].issuedAt != v.issuedAt,
            "Locking proof must be issued separately from updating proof.");
        require(block.timestamp < _credentials[v.id].issuedAt + 1 hours,
            "Credential must be locked within an hour of updating.");
        require(_equal(_credentials[v.id].city, v.city),
            "Not sure how that happened.");
        require(block.timestamp < v.issuedAt + 10 minutes,
            "Credential must be issued less than 10 minutes ago.");
        require(block.timestamp >= v.issuedAt,
            "Block somehow older than the credential?");

        ISP1Verifier(verifier).verifyProof(mdlCityProgramVKey, _publicValues, _proofBytes);

        _credentials[v.id].locked = true;
        _credentials[v.id].lockedAt = block.timestamp;
    }

    function unlockCredential(uint256 id)
        public
    {
        require(_credentials[id].owner == msg.sender,
            "Credential can only be unlocked by its owner.");
        _credentials[id].locked = false;
        _credentials[id].lockedAt = 0;
    }


    function ownerCredentialIds(address owner)
        public
        view
        returns(uint256[] memory)
    {
        return _ownedTokens[owner];
    }


    function credentialOfOwnerByIndex(address owner, uint256 index)
        public
        view
        returns(Credential memory)
    {
        return _credentials[_ownedTokens[owner][index]];
    }


    function balanceOf(address owner)
        override(ERC721)
        public
        view
        returns(uint256)
    {
        return _ownedTokens[owner].length;
    }


    function ownerOf(uint256 _tokenId)
        override(ERC721)
        public
        view
        returns(address)
    {
        return _credentials[_tokenId].owner;
    }

    function credential(uint256 id)
        public
        view
        returns(Credential memory)
    {
        return _credentials[id];
    }


    function _removeCredential(address owner, uint256 id)
        internal
    {
        uint256 index;
        bool found = false;

        for(uint256 i = 0; i < _ownedTokens[owner].length; i++) {
            if(_ownedTokens[owner][i] == id) {
                index = i;
                found = true;
                break;
            }
        }

        if(!found) {
            return;
        }

        _ownedTokens[owner][index] = _ownedTokens[owner][_ownedTokens[owner].length - 1];
        _ownedTokens[owner].pop();
    }

    function _equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "";
    }


    // Overriding most base NFT functionality.

    function approve(address to, uint256 tokenId) public pure override(ERC721) {
        revert ErrorFunctionDisabled();
    }

    function getApproved(uint256 tokenId) public pure override(ERC721) returns (address) {
        revert ErrorFunctionDisabled();
    }

    function setApprovalForAll(address operator, bool approved) public pure override(ERC721) {
        revert ErrorFunctionDisabled();
    }

    function isApprovedForAll(address owner, address operator) public pure override(ERC721) returns (bool) {
        revert ErrorFunctionDisabled();
    }

    function transferFrom(address from, address to, uint256 tokenId) public pure override(ERC721) {
        revert ErrorFunctionDisabled();
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public pure override(ERC721) {
        revert ErrorFunctionDisabled();
    }




}
