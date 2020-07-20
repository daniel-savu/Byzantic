pragma solidity ^0.5.0;

import "./LBCR.sol";
import "./WebOfTrust.sol";
import "./UserProxy.sol";
import "./SimpleLendingProxy.sol";
import "@nomiclabs/buidler/console.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";


contract UserProxyFactory is Ownable {
    mapping (address => UserProxy) userAddressToUserProxy;
    mapping (address => address) userProxyToUserAddress;

    LBCR simpleLendingLBCR;
    LBCR simpleLendingTwoLBCR;
    WebOfTrust webOfTrust;
    mapping (address => bool) isAgentInitialized;

    constructor(
        address simpleLendingLBCRAddress,
        address simpleLendingTwoLBCRAddress,
        address payable webOfTrustAddress
    ) public {
        simpleLendingLBCR = LBCR(simpleLendingLBCRAddress);
        simpleLendingTwoLBCR = LBCR(simpleLendingTwoLBCRAddress);
        webOfTrust = WebOfTrust(webOfTrustAddress);
    }

    function() external payable {}

    function addAgent() public {
        if (!isAgentInitialized[msg.sender]) {
            UserProxy userProxy = new UserProxy(msg.sender, address(webOfTrust));
            userAddressToUserProxy[msg.sender] = userProxy;
            userProxyToUserAddress[address(userProxy)] = msg.sender;
            simpleLendingLBCR.registerAgent(address(userProxy));
            simpleLendingTwoLBCR.registerAgent(address(userProxy));
            // add other protocol initializations here
            // such as initializeCompoundProxy when done
            isAgentInitialized[msg.sender] = true;
        }
    }

    function isAddressAByzanticProxy(address userProxyAddress) public view returns (bool) {
        return userProxyToUserAddress[userProxyAddress] != address(0);
    }

    function getUserProxyAddress(address userAddress) public view returns (address payable) {
        return address(userAddressToUserProxy[userAddress]);
    }

}