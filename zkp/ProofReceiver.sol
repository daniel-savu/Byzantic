
mapping(address => bytes32[2]) reputationAddressAuthenticator


function proveIdentityAndCall(
	address reputationAddress, 
	bytes32 firstNewHashValue, 
	bytes32 secondNewHashValue, 
	bytes32[] calldata proof,
	// the following is a call encoding for Byzantic after the validation succeeds
	bytes memory protocolCallAbiEncoding
) {
	(uint[2] memory a, uint[2][2] memory b, uint[2] memory c, uint[3] memory inputs) = extractProof(proof);

    // reputationAddressAuthenticator is a mapping(address => bytes32) that stores the authentication hash for every Byzantic account
	require(reputationAddressAuthenticator[reputationAddress][0] == address(inputs[0]), "authentication hash mismatch" );
	require(reputationAddressAuthenticator[reputationAddress][1] == address(inputs[1]), "authentication hash mismatch" );


	bool isValid = IProofValidator(validatorContract).verifyTx(a, b, c, inputs);
	require(isValid == true, "proof failed");

    // update the authentication hash to prevent double-calls of this msg.data
	reputationAddressAuthenticator[reputationAddress][0] = firstNewHashValue;
	reputationAddressAuthenticator[reputationAddress][1] = secondNewHashValue;

	// make Byzantic call on behalf of reputationAddress
	UserProxy userProxy = UserProxy(userProxyFactory.getUserProxyAddress(reputationAddress));
	userProxy.call(protocolCallAbiEncoding ...)
}