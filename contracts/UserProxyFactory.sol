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

    LBCR[] lbcrs;
    WebOfTrust webOfTrust;
    mapping (address => bool) isAgentInitialized;

    constructor(address payable webOfTrustAddress) public {
        webOfTrust = WebOfTrust(webOfTrustAddress);
    }

    function() external payable {}

    function addAgent() public {
        if (!isAgentInitialized[msg.sender]) {
            UserProxy userProxy = new UserProxy(msg.sender, address(webOfTrust));
            userAddressToUserProxy[msg.sender] = userProxy;
            userProxyToUserAddress[address(userProxy)] = msg.sender;

            for(uint i = 0; i < lbcrs.length; i++) {
                lbcrs[i].registerAgent(address(userProxy));
            }

            isAgentInitialized[msg.sender] = true;
        }
    }

    function addLBCR(address lbcrAddress) public onlyOwner {
        LBCR lbcr = LBCR(lbcrAddress);
        lbcrs.push(lbcr);
    }

    function isAddressAByzanticProxy(address userProxyAddress) public view returns (bool) {
        return userProxyToUserAddress[userProxyAddress] != address(0);
    }

    function getUserProxyAddress(address userAddress) public view returns (address payable) {
        return address(userAddressToUserProxy[userAddress]);
    }

}