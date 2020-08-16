pragma solidity ^0.5.0;

// import "../zkp/verifier.sol";
import "./IProofValidator.sol";

contract ZkIdentity {

    mapping(address => bytes32[2]) reputationAddressAuthenticator;
    address validatorContract;
    
    // constructor(
    //     address validatorContractAddress
    // ) public {
    //     validatorContract = validatorContractAddress;
    // }

    function setReputationAddressAuthentication(bytes32 firstHalfOfHash, bytes32 secondHalfOfHash) external {
        reputationAddressAuthenticator[msg.sender][0] = firstHalfOfHash;
        reputationAddressAuthenticator[msg.sender][1] = secondHalfOfHash;
    }

    function proveIdentityAndCall(
        address reputationAddress, 
        bytes32 firstNewHashValue, 
        bytes32 secondNewHashValue, 
        bytes32[] calldata proof
    ) external returns (bool) {
        (uint[2] memory a, uint[2][2] memory b, uint[2] memory c, uint[3] memory inputs) = extractProof(proof);

        // reputationAddressAuthenticator is a mapping(address => bytes32) that stores the authentication hash for every Byzantic account
        require(reputationAddressAuthenticator[reputationAddress][0] == bytes32(inputs[0]), "authentication hash mismatch" );
        require(reputationAddressAuthenticator[reputationAddress][1] == bytes32(inputs[1]), "authentication hash mismatch" );

        bool isValid = IProofValidator(validatorContract).verifyTx(a, b, c, inputs);
        require(isValid == true, "identity proof failed");

        // update the authentication hash to prevent double-calls of this msg.data
        reputationAddressAuthenticator[reputationAddress][0] = firstNewHashValue;
        reputationAddressAuthenticator[reputationAddress][1] = secondNewHashValue;

        return true;
    }

    function extractProof(bytes32[] memory proof) internal pure returns (uint[2] memory a, uint[2][2] memory b, uint[2] memory c, uint[3] memory inputs) {
        a[0] = uint256(proof[0]);
        a[1] = uint256(proof[1]);

        b[0][0] = uint256(proof[2]);
        b[0][1] = uint256(proof[3]);
        b[1][0] = uint256(proof[4]);
        b[1][1] = uint256(proof[5]);

        c[0] = uint256(proof[6]);
        c[1] = uint256(proof[7]);

        inputs[0] = uint256(proof[8]);
        inputs[1] = uint256(proof[9]);
        inputs[2] = uint256(proof[10]);
    }

}