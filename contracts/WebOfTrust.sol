pragma solidity ^0.5.0;

// import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@nomiclabs/buidler/console.sol";
import "./LBCR.sol";
import "./UserProxy.sol";
import "./SimpleLending/SimpleLending.sol";
import "./SimpleLendingProxy.sol";
import "./UserProxyFactory.sol";
import "./ILBCR.sol";
import "./IByzantic.sol";
// import "node_modules/@studydefi/money-legos/compound/contracts/ICEther.sol";


contract WebOfTrust {
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    UserProxyFactory userProxyFactory;
    LBCR[] lbcrs;
    mapping (address => address) protocolToLBCR;
    mapping (address => address) protocolToProxy;
    uint userFactorDecimals;

    constructor() public {
        userProxyFactory = new UserProxyFactory(address(this));
        userFactorDecimals = 3;
    }

    function() external payable {
        console.log("reached the fallback");
    }

    function addProtocolIntegration(address protocolAddress, address protocolProxyAddress) external {
        require(protocolToLBCR[protocolAddress] == address(0), "protocol has already been added");
        LBCR lbcr = new LBCR();
        protocolToLBCR[protocolAddress] = address(lbcr);
        lbcr.addAuthorisedContract(address(userProxyFactory));
        lbcrs.push(lbcr);
        userProxyFactory.addLBCR(address(lbcr));
        protocolToProxy[protocolAddress] = protocolProxyAddress;
    }

    function getUserProxyFactoryAddress() public view returns (address) {
        return address(userProxyFactory);
    }

    function getProtocolLBCR(address protocolAddress) public view returns (address) {
        return protocolToLBCR[protocolAddress];
    }

    function updateLBCR(address protocolAddress, address agent, uint256 action) public {
        address proxyAddress = protocolToProxy[protocolAddress];
        require(
            proxyAddress == msg.sender,
            "caller is either not a registered protocol or not the proxy of the destination protocol"
        );
        LBCR lbcr = LBCR(protocolToLBCR[protocolAddress]);
        lbcr.update(agent, action);
    }

    /**
     * @dev Uses information from all LBCRs and the subjective measures
     * of compatibility between them to compute how much collateral a
     * user should pay.
     */
    function getAggregateAgentFactorForProtocol(address agent, address protocol) public view returns (uint256) {
        // a factor of 1500 is equal to 1.5 times the collateral
        uint aggregateAgentFactor = aggregateLBCRsForProtocol(agent, protocol);
        return aggregateAgentFactor;
    }

    function aggregateLBCRsForProtocol(address agent, address protocol) public view returns (uint) {
        uint agentFactorSum = 0;
        uint agentFactorDenominator = 0;
        address LBCRAddress = protocolToLBCR[protocol];

        for(uint i = 0; i < lbcrs.length; i ++) {
            LBCR lbcr = lbcrs[i];
            if(lbcr.getInteractionCount(agent) > 0) {
                agentFactorSum += (lbcr.getAgentFactor(agent) * ILBCR(LBCRAddress).getCompatibilityScoreWith(address(lbcr)));
                agentFactorDenominator += ILBCR(LBCRAddress).getCompatibilityScoreWith(address(lbcr));
            }
        }
        if(agentFactorDenominator > 0) {
            return agentFactorSum / agentFactorDenominator;
        }
        return 1000;
    }

    function curateLBCRs() public {
        for(uint i = 0; i < lbcrs.length; i++) {
            lbcrs[i].curate();
        }
    }

    function getUserFactorDecimals() public view returns (uint){
        return userFactorDecimals;
    }

}