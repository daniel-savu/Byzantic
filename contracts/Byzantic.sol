pragma solidity ^0.5.0;

// import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@nomiclabs/buidler/console.sol";
import "./LBCR.sol";
import "./UserProxy.sol";
import "./SimpleLending/SimpleLending.sol";
import "./SimpleLendingProxy.sol";
import "./SimpleLendingTwoProxy.sol";
import "./UserProxyFactory.sol";
import "./ILBCR.sol";
// import "node_modules/@studydefi/money-legos/compound/contracts/ICEther.sol";


contract Byzantic {
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    UserProxyFactory userProxyFactory;
    LBCR[] lbcrs;
    mapping (address => address) protocolToLBCR;

    LBCR simpleLendingLBCR;
    LBCR simpleLendingTwoLBCR;

    SimpleLending simpleLending;
    SimpleLending simpleLendingTwo;

    SimpleLendingProxy simpleLendingProxy;
    SimpleLendingTwoProxy simpleLendingTwoProxy;

    constructor() public {
        uint baseCollateralisationRateValue = 1500;

        simpleLendingLBCR = new LBCR();
        simpleLendingLBCR.addAuthorisedContract(address(userProxyFactory));
        simpleLending = new SimpleLending(address(this), baseCollateralisationRateValue);

        simpleLendingTwoLBCR = new LBCR();
        simpleLendingTwoLBCR.addAuthorisedContract(address(userProxyFactory));
        simpleLendingTwo = new SimpleLending(address(this), baseCollateralisationRateValue);

        simpleLendingLBCR.setCompatibilityScoreWith(address(simpleLendingTwoLBCR), 50);
        simpleLendingTwoLBCR.setCompatibilityScoreWith(address(simpleLendingLBCR), 50);

        lbcrs.push(simpleLendingLBCR);
        lbcrs.push(simpleLendingTwoLBCR);

        protocolToLBCR[address(simpleLending)] = address(simpleLendingLBCR);
        protocolToLBCR[address(simpleLendingTwo)] = address(simpleLendingTwoLBCR);

        userProxyFactory = new UserProxyFactory(
            address(simpleLendingLBCR),
            address(simpleLendingTwoLBCR),
            address(this)
        );
        
        simpleLendingProxy = new SimpleLendingProxy(
            address(simpleLendingLBCR),
            address(this),
            address(userProxyFactory)
        );

        simpleLendingTwoProxy = new SimpleLendingTwoProxy(
            address(simpleLendingTwoLBCR),
            address(this),
            address(userProxyFactory)
        );
    }

    function() external payable {
        console.log("reached the fallback");
    }

    function getUserProxyFactoryAddress() public view returns (address) {
        return address(userProxyFactory);
    }

    function getSimpleLendingLBCR() public view returns (address) {
        return address(simpleLendingLBCR);
    }

    function getSimpleLendingTwoLBCR() public view returns (address) {
        return address(simpleLendingTwoLBCR);
    }

    function getSimpleLendingAddress() public view returns (address) {
        return address(simpleLending);
    }

    function getSimpleLendingTwoAddress() public view returns (address) {
        return address(simpleLendingTwo);
    }

    function getAggregateAgentFactorForProtocol(address agent, address protocol) public returns (uint256) {
        // a factor of 1500 is equal to 1.5 times the collateral
        uint aggregateAgentFactor = aggregateLBCRsForProtocol(agent, protocol);
        console.log("aggregateAgentFactorForProtocol:");
        console.log(aggregateAgentFactor);
        return aggregateAgentFactor;
    }

    function aggregateLBCRsForProtocol(address agent, address protocol) public returns (uint) {
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

    function moveFundsToUserProxy(address agentOwner, address _reserve, uint _amount) public {
        // this method assumes proxies will never ask for more funds than they have
        if(_reserve != aETHAddress) {
            IERC20(_reserve).transfer(msg.sender, _amount);
        } else {
            msg.sender.transfer(_amount);
        }
    }

    function setSimpleLendingProxy(address payable simpleLendingProxyAddress) public {
        simpleLendingProxy = SimpleLendingProxy(simpleLendingProxyAddress);
    }

    function getSimpleLendingProxy()  public view returns (address) {
        return address(simpleLendingProxy);
    }

    function getSimpleLendingTwoProxy()  public view returns (address) {
        return address(simpleLendingTwoProxy);
    }

    function curateLBCRs() public {
        simpleLendingLBCR.curate();
        simpleLendingTwoLBCR.curate();
    }

}