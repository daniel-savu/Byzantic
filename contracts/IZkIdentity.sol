pragma solidity ^0.5.0;


interface IZkIdentity {
    function proveIdentityAndCall(
        address reputationAddress, 
        bytes32 firstNewHashValue, 
        bytes32 secondNewHashValue, 
        bytes32[] calldata proof
    ) external returns (bool);

    function setReputationAddressAuthentication(bytes32 firstHalfOfHash, bytes32 secondHalfOfHash) external;
}