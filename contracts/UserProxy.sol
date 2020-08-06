pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IWebOfTrust.sol";
import "./LBCR.sol";
import "@nomiclabs/buidler/console.sol";


contract UserProxy is Ownable {
    address agentOwner;
    uint256 constant INT256_MAX = ~(uint256(1) << 255);

    // only callable by (all the) user protocol proxies
    address[] authorisedContracts;
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant LendingPoolAddressesProviderAddress = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;
    mapping(address => int256) agentFundsInPool;
    LBCR[] lbcrs;
    address webOfTrustAddress;


    constructor(address agent, address payable webOfTrustAddressValue) public {
        webOfTrustAddress = webOfTrustAddressValue;
        addAuthorisedContract(msg.sender);
        agentOwner = agent;
    }

    function() external payable {}

    function addAuthorisedContract(address authorisedContract) public onlyAuthorised {
        authorisedContracts.push(authorisedContract);
    }

    modifier onlyAuthorised() {
        bool isAuthorised = false;
        if(isOwner()) {
            isAuthorised = true;
        }
        for (uint i = 0; i < authorisedContracts.length; i++) {
            if(authorisedContracts[i] == msg.sender) {
                isAuthorised = true;
                break;
            }
        }
        require(isAuthorised == true, "Caller is not authorised to perform this action");
        _;
    }

    modifier onlyAgentOwner() {
        require(msg.sender == agentOwner, "Caller isn't agentOwner");
        _;
    }

    modifier onlyProtocolProxies() {
        require(IWebOfTrust(webOfTrustAddress).isProtocolProxy(msg.sender), "Caller is not protocol proxy");
        _;
    }

    function hasEnoughFunds(address reserve, uint amount) internal returns (bool) {
        if(reserve != aETHAddress) {
            return IERC20(reserve).balanceOf(address(this)) >= amount;
        } else {
            return address(this).balance >= amount;
        }
    }

    function withdrawFunds(address _reserve, uint256 _amount) external onlyAgentOwner {
        require(hasEnoughFunds(_reserve, _amount), "You don't have enough funds");
        if(_reserve != aETHAddress) {
            IERC20(_reserve).transfer(msg.sender, _amount);
        } else {
            msg.sender.transfer(_amount);
        }
    }

    function depositFunds(address _reserve, uint256 _amount) external payable onlyAgentOwner {
        if(_reserve == aETHAddress) {
            require(msg.value == _amount, "_amount does not match the sent ETH");
        } else {
            IERC20(_reserve).transferFrom(msg.sender, address(this), _amount);
        }
    }

    function getReserveBalance(address _reserve) external view returns(uint256) {
        if(_reserve != aETHAddress) {
            return IERC20(_reserve).balanceOf(address(this));
        } else {
            return address(this).balance;
        }
    }

    function proxyCall(address target, bytes memory abiEncoding) public onlyProtocolProxies returns (bool) {
        // the following variables are set to 0 because they are not applicable to this call
        address currencyReserve = address(0);
        uint256 currencyAmount = 0;
        bool proxyCallResult = proxyCall(target, abiEncoding, currencyReserve, currencyAmount);
        return proxyCallResult;
    }

    function proxyCall(
        address target,
        bytes memory abiEncoding,
        address reserve,
        uint256 amount
    ) public onlyProtocolProxies returns (bool) {
        require(target != address(0), "Target address cannot be 0");
        if(reserve != address(0)) {
            require(hasEnoughFunds(reserve, amount), "You don't have enough funds");
        }
        bool success;

        if(amount > 0) {
            require(reserve != address(0), "Reserve address cannot be 0");
            if(reserve != aETHAddress) {
                IERC20(reserve).approve(target, amount);
                (success, ) = target.call(abiEncoding);
            } else {
                (success, ) = target.call.value(amount)(abiEncoding);
            }
        } else {
            (success, ) = target.call(abiEncoding);
        }
        return success;
    }

}


