pragma solidity ^0.5.0;

import "./LBCR.sol";
import "./WebOfTrust.sol";
import "./UserProxy.sol";
import "@nomiclabs/buidler/console.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";


contract UserProxyFactory is Ownable {
    mapping (address => UserProxy) userAddressToUserProxy;
    mapping (address => address) userProxyToUserAddress;

    LBCR[] lbcrs;
    WebOfTrust webOfTrust;
    mapping (address => bool) isAgentInitialized;
    address[] agents;

    constructor(address payable webOfTrustAddress) public {
        webOfTrust = WebOfTrust(webOfTrustAddress);
    }

    function() external payable {}

    /// @notice Register user into all LBCRs in Byzantic and deploy a personalised UserProxy contract
    /// @param agent The address of the user whose to register to Byzantic
    function registerAgent(address agent) public onlyOwner {
        if (!isAgentInitialized[agent]) {
            UserProxy userProxy = new UserProxy(agent, address(webOfTrust));
            userAddressToUserProxy[agent] = userProxy;
            userProxyToUserAddress[address(userProxy)] = agent;

            for(uint i = 0; i < lbcrs.length; i++) {
                lbcrs[i].registerAgent(address(userProxy));
            }

            isAgentInitialized[agent] = true;
            agents.push(agent);
        }
    }

    /// @notice Function called by the WebOfTrust contract to registers all Byzantic users to a new LBCR
    function addLBCR(address lbcrAddress) public onlyOwner {
        LBCR lbcr = LBCR(lbcrAddress);
        require(!lbcrAlreadyAdded(lbcr), "lbcr already added in user proxy");
        lbcrs.push(lbcr);
        for(uint i = 0; i < agents.length; i++) {
            lbcr.registerAgent(agents[i]);
        }
    }

    function lbcrAlreadyAdded(LBCR lbcr) private view returns(bool) {
        for (uint8 i = 0; i < lbcrs.length; i++) {
            if(address(lbcrs[i]) == address(lbcr)) {
                return true;
            }
        }
        return false;
    }

    function isUserProxy(address userProxyAddress) external view returns (bool) {
        return userProxyToUserAddress[userProxyAddress] != address(0);
    }

    function getUserProxyAddress(address userAddress) external view returns (address payable) {
        return address(userAddressToUserProxy[userAddress]);
    }

    function isAgentRegistered(address agent) public view returns (bool) {
        return isAgentInitialized[agent];
    }

}