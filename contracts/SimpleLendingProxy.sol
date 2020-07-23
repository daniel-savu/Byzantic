pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LBCR.sol";
import "@nomiclabs/buidler/console.sol";
import "./WebOfTrust.sol";
import "./UserProxy.sol";
import "./UserProxyFactory.sol";
import "./SimpleLending/SimpleLending.sol";

// import "./InitializableAdminUpgradeabilityProxy.sol";

contract SimpleLendingProxy is Ownable {
    address constant LendingPoolAddressesProviderAddress = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant aETHContractAddress = 0x3a3A65aAb0dd2A17E3F1947bA16138cd37d08c04;

    uint256 depositAction;
    uint256 borrowAction;
    uint256 repayAction;
    uint256 liquidateAction;
    uint256 flashLoanAction;
    uint256 redeemAction;
    WebOfTrust webOfTrust;
    UserProxyFactory userProxyFactory;
    SimpleLending simpleLending;

    constructor(
        address payable webOfTrustAddress,
        address payable UserProxyFactoryAddress,
        address payable simpleLendingAddress
    ) public {
        webOfTrust = WebOfTrust(webOfTrustAddress);
        userProxyFactory = UserProxyFactory(UserProxyFactoryAddress);
        simpleLending = SimpleLending(simpleLendingAddress);
        depositAction = 1;
        borrowAction = 2;
        repayAction = 3;
        liquidateAction = 4;
        flashLoanAction = 5;
        redeemAction = 6;
    }

    function() external payable {}

    function setSimpleLendingAddress(address payable simpleLendingAddress) public onlyOwner {
        simpleLending = SimpleLending(simpleLendingAddress);
    }


    // SimpleLending protocol methods

    // LendingPool contract

    function deposit(address reserve, uint256 amount) public {
        bytes memory abiEncoding = abi.encodeWithSignature(
            "deposit(address,uint256)",
            reserve,
            amount
        );
        UserProxy userProxy = UserProxy(userProxyFactory.getUserProxyAddress(msg.sender));
        bool success = userProxy.proxyCall(address(simpleLending), abiEncoding, reserve, amount);
        require(success, "deposit failed");
        webOfTrust.updateLBCR(address(simpleLending), address(userProxy), depositAction);
    }

    function borrow(address reserve, uint256 amount) public {
        bytes memory abiEncoding = abi.encodeWithSignature(
            "borrow(address,uint256)",
            reserve,
            amount
        );
        UserProxy userProxy = UserProxy(userProxyFactory.getUserProxyAddress(msg.sender));
        bool success = userProxy.proxyCall(address(simpleLending), abiEncoding);
        require(success, "borrow failed");
        webOfTrust.updateLBCR(address(simpleLending), address(userProxy), depositAction);
    }

    function repay(address reserve, uint256 amount, address onbehalf) public {
        bytes memory abiEncoding = abi.encodeWithSignature(
            "repay(address,uint256,address)",
            reserve,
            amount,
            onbehalf
        );
        UserProxy userProxy = UserProxy(userProxyFactory.getUserProxyAddress(msg.sender));
        bool success = userProxy.proxyCall(address(simpleLending), abiEncoding, reserve, amount);
        require(success, "repayment failed");
        webOfTrust.updateLBCR(address(simpleLending), address(userProxy), depositAction);
    }

    function liquidate(address borrower, address collateralReserve, address loanReserve, uint256 loanAmount) public {
        bytes memory abiEncoding = abi.encodeWithSignature(
            "liquidate(address,address,address,uint256)",
            borrower,
            collateralReserve,
            loanReserve,
            loanAmount
        );
        UserProxy userProxy = UserProxy(userProxyFactory.getUserProxyAddress(msg.sender));
        bool success = userProxy.proxyCall(address(simpleLending), abiEncoding, loanReserve, loanAmount);
        require(success, "liquidation failed");
        webOfTrust.updateLBCR(address(simpleLending), address(userProxy), depositAction);
    }

    function redeem(address reserve, uint256 amount) public {
        bytes memory abiEncoding = abi.encodeWithSignature(
            "redeem(address,uint256)",
            reserve,
            amount
        );
        UserProxy userProxy = UserProxy(userProxyFactory.getUserProxyAddress(msg.sender));
        bool success = userProxy.proxyCall(address(simpleLending), abiEncoding);
        require(success, "redeem failed");
        webOfTrust.updateLBCR(address(simpleLending), address(userProxy), depositAction);
    }

}


