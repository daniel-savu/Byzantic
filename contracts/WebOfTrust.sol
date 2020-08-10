pragma solidity ^0.5.0;

// import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@nomiclabs/buidler/console.sol";
import "./LBCR.sol";
import "./UserProxy.sol";
import "./UserProxyFactory.sol";
import "./ILBCR.sol";

/// @title Registers users, protocols, aggregates reputation
contract WebOfTrust {
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    UserProxyFactory userProxyFactory;
    LBCR[] lbcrs;
    mapping (address => address) protocolToLBCR;
    mapping (address => address) protocolToProxy;
    mapping (address => bool) protocolProxy;
    uint agentFactorDecimals;

    constructor() public {
        userProxyFactory = new UserProxyFactory(address(this));
        agentFactorDecimals = 3;
    }

    function() external payable {
        console.log("reached the fallback");
    }

    /// @notice Sign up with Byzantic as a user
    function registerAgent() external {
        userProxyFactory.registerAgent(msg.sender);
    }

    /// @notice Check if agent has signed up with Byzantic
    /// @param agent The address of `msg.sender` when calling `registerAgent()`
    /// @return isAgentRegistered boolean value representing the membership of the agent in Byzantic
    function isAgentRegistered(address agent) public view returns (bool) {
        return userProxyFactory.isAgentRegistered(agent);
    }

    /// @notice Integrate your protocol with Byzantic
    /// @dev You need to deploy a Proxy contract for your protocol to integrate with Byzantic. 
    /// After calling `addProtocolIntegration`, you need to call `getProtocolLBCR` and configure your LBCR.
    /// @param protocolAddress The address of the contract in your protocol you want to integrate with Byzantic.
    /// @param protocolProxyAddress The address of the proxy to your contract. Written in the same style as the `SimpleLendingProxy` example contract.
    function addProtocolIntegration(address protocolAddress, address protocolProxyAddress) external {
        require(protocolToLBCR[protocolAddress] == address(0), "protocol has already been added");
        LBCR lbcr = new LBCR();
        protocolToLBCR[protocolAddress] = address(lbcr);
        lbcr.addAuthorisedContract(address(userProxyFactory));
        lbcr.addAuthorisedContract(msg.sender);
        lbcrs.push(lbcr);
        userProxyFactory.addLBCR(address(lbcr));
        protocolToProxy[protocolAddress] = protocolProxyAddress;
        protocolProxy[protocolProxyAddress] = true;
    }

    /// @return userProxyFactoryAddress The address of the UserProxyFactory contract
    function getUserProxyFactoryAddress() public view returns (address) {
        return address(userProxyFactory);
    }

    /// @return LBCR The address of the LBCR contract of a given protocol
    function getProtocolLBCR(address protocolAddress) public view returns (address) {
        return protocolToLBCR[protocolAddress];
    }

    /// @notice Record a user action into the LBCR, to update their score
    /// @dev The `require` statement replaces a modifier that prevents unauthorised calls
    /// @param protocolAddress The address of the contract in your protocol you want to integrate with Byzantic.
    /// @param agent The address of the user whose reputation is being updated in the LBCR
    /// @param action The action that the user has performed and is being rewarded / punished for.
    function updateLBCR(address protocolAddress, address agent, uint256 action) public {
        address proxyAddress = protocolToProxy[protocolAddress];
        require(
            proxyAddress == msg.sender,
            "caller is either not a registered protocol or not the proxy of the destination protocol"
        );
        LBCR lbcr = LBCR(protocolToLBCR[protocolAddress]);
        lbcr.update(agent, action);
    }

    /// @notice Uses information from all LBCRs and the subjective measures
    /// of compatibility between them to compute how much collateral a
    /// user should pay. 
    /// @param agent The address of the user whose reputation is being computed
    /// @param protocol Address of the protocol with respect to which the reputation is being computed.
    /// @return DiscountedCollateral - User reputation, expressed as the percentage of collateral they need to pay.
    /// A return value of 900 means the agent only needs
    /// to pay 90% of the normally required collateral (so the result needs to be divided by 10^3).
    /// If the agent has not signed up with Byzantic, they need to pay the full collateral (100%)
    function getAggregateAgentFactorForProtocol(address agent, address protocol) external view returns (uint256) {
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

        // agent has not signed up with Byzantic
        return 1000;
    }

    /// @notice For each of the LBCRs in Byzantic, if the round has elapsed, users will be curated into layers according to their score
    function curateLBCRs() public {
        for(uint i = 0; i < lbcrs.length; i++) {
            lbcrs[i].curateIfRoundEnded();
        }
    }

    /// @return agentFactorDecimals Number of decimals used to express the aggregate agent factor returned by `getAggregateAgentFactorForProtocol()`
    function getAgentFactorDecimals() external view returns (uint) {
        return agentFactorDecimals;
    }

    function isProtocolProxy(address addr) external returns (bool) {
        return protocolProxy[addr];
    }

    function getProtocolProxy(address addr) external returns (address) {
        return protocolToProxy[addr];
    }

}