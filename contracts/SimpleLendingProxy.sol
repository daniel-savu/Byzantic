pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@nomiclabs/buidler/console.sol";
import "./WebOfTrust.sol";
import "./UserProxy.sol";
import "./UserProxyFactory.sol";
import "./IZkIdentity.sol";

/// @notice Example contract to act as a Protocol Proxy template
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
    address payable simpleLendingAddress;
    address zkIdentityAddress;

    constructor(
        address payable webOfTrustAddress,
        address payable UserProxyFactoryAddress,
        address payable simpleLendingAddressValue,
        address zkIdentityAddressValue
    ) public {
        webOfTrust = WebOfTrust(webOfTrustAddress);
        userProxyFactory = UserProxyFactory(UserProxyFactoryAddress);
        simpleLendingAddress = simpleLendingAddressValue;
        zkIdentityAddress = zkIdentityAddressValue;
        depositAction = 1;
        borrowAction = 2;
        repayAction = 3;
        liquidateAction = 4;
        flashLoanAction = 5;
        redeemAction = 6;
    }

    function() external payable {}

    function setSimpleLendingAddress(address payable simpleLendingAddressValue) public onlyOwner {
        simpleLendingAddress = simpleLendingAddressValue;
    }


    // SimpleLending protocol methods

    // LendingPool contract

    function userProxyCall(
        bytes memory abiEncoding, 
        address callerAddress, 
        uint256 action, 
        address reserve, 
        uint256 amount
    ) private {
        UserProxy userProxy = UserProxy(userProxyFactory.getUserProxyAddress(callerAddress));
        bool success = userProxy.proxyCall(simpleLendingAddress, abiEncoding, reserve, amount);
        require(success, "SimpleLending action failed");
        webOfTrust.updateLBCR(simpleLendingAddress, address(userProxy), action);
    }

    function userProxyCall(
        bytes memory abiEncoding, 
        address callerAddress, 
        uint256 action
    ) private {

        UserProxy userProxy = UserProxy(userProxyFactory.getUserProxyAddress(callerAddress));
        bool success = userProxy.proxyCall(simpleLendingAddress, abiEncoding);
        require(success, "SimpleLending action failed");
        webOfTrust.updateLBCR(simpleLendingAddress, address(userProxy), action);
    }

    function depositPrivately(
        address reputationAddress, 
        bytes32 firstNewHashValue, 
        bytes32 secondNewHashValue, 
        bytes32[] memory proof,
        address reserve,
        uint256 amount
    ) public {
        bool isIdentityProofValid = IZkIdentity(zkIdentityAddress).proveIdentity(reputationAddress, firstNewHashValue, secondNewHashValue, proof);
        require(isIdentityProofValid, "invalid identity proof");

        bytes memory abiEncoding = abi.encodeWithSignature(
            "deposit(address,uint256)",
            reserve,
            amount
        );
        userProxyCall(abiEncoding, reputationAddress, depositAction, reserve, amount);
    }

    /// @notice Function that packs the call to the `deposit` function in `SimpleLending` as an abi enconding and then calls 
    /// the `msg.sender`'s `UserProxy` to call `SimpleLending` with the abi encoding
    /// @param reserve Addres of asset to deposit in `SimpleLending`
    /// @param amount Quantity of `reserve` to deposit in `SimpleLending`
    function deposit(address reserve, uint256 amount) public {
        bytes memory abiEncoding = abi.encodeWithSignature(
            "deposit(address,uint256)",
            reserve,
            amount
        );
        userProxyCall(abiEncoding, msg.sender, depositAction, reserve, amount);
    }

    function borrowPrivately(
        address reputationAddress, 
        bytes32 firstNewHashValue, 
        bytes32 secondNewHashValue, 
        bytes32[] memory proof,
        address reserve,
        uint256 amount
    ) public {
        bool isIdentityProofValid = IZkIdentity(zkIdentityAddress).proveIdentity(reputationAddress, firstNewHashValue, secondNewHashValue, proof);
        require(isIdentityProofValid, "invalid identity proof");

        bytes memory abiEncoding = abi.encodeWithSignature(
            "borrow(address,uint256)",
            reserve,
            amount
        );
        userProxyCall(abiEncoding, reputationAddress, borrowAction);
    }

    /// @notice Function that packs the call to the `borrow` function in `SimpleLending` as an abi enconding and then calls 
    /// the `msg.sender`'s `UserProxy` to call `SimpleLending` with the abi encoding
    /// @param reserve Addres of asset to borrow from `SimpleLending`
    /// @param amount Quantity of `reserve` to borrow from `SimpleLending`
    function borrow(address reserve, uint256 amount) public {
        bytes memory abiEncoding = abi.encodeWithSignature(
            "borrow(address,uint256)",
            reserve,
            amount
        );
        userProxyCall(abiEncoding, msg.sender, borrowAction);
    }

    function repayPrivately(
        address reputationAddress, 
        bytes32 firstNewHashValue, 
        bytes32 secondNewHashValue, 
        bytes32[] memory proof,
        address reserve,
        uint256 amount,
        address onbehalf
    ) public {
        bool isIdentityProofValid = IZkIdentity(zkIdentityAddress).proveIdentity(reputationAddress, firstNewHashValue, secondNewHashValue, proof);
        require(isIdentityProofValid, "invalid identity proof");

        bytes memory abiEncoding = abi.encodeWithSignature(
            "repay(address,uint256,address)",
            reserve,
            amount,
            onbehalf
        );
        userProxyCall(abiEncoding, reputationAddress, repayAction, reserve, amount);
    }

    /// @notice Function that packs the call to the `repay` function (repaying a loan) in `SimpleLending` as an abi enconding and then calls 
    /// the `msg.sender`'s `UserProxy` to call `SimpleLending` with the abi encoding
    /// @param reserve Addres of asset to repay to `SimpleLending`
    /// @param amount Quantity of `reserve` to repay to `SimpleLending`
    /// @param onbehalf User to repay the bloan on behalf of
    function repay(address reserve, uint256 amount, address onbehalf) public {
        bytes memory abiEncoding = abi.encodeWithSignature(
            "repay(address,uint256,address)",
            reserve,
            amount,
            onbehalf
        );
        userProxyCall(abiEncoding, msg.sender, repayAction, reserve, amount);
    }

    function liquidatePrivately(
        address reputationAddress, 
        bytes32 firstNewHashValue, 
        bytes32 secondNewHashValue, 
        bytes32[] memory proof,
        address borrower,
        address collateralReserve,
        address loanReserve,
        uint256 loanAmount
    ) public {
        bool isIdentityProofValid = IZkIdentity(zkIdentityAddress).proveIdentity(reputationAddress, firstNewHashValue, secondNewHashValue, proof);
        require(isIdentityProofValid, "invalid identity proof");

        bytes memory abiEncoding = abi.encodeWithSignature(
            "liquidate(address,address,address,uint256)",
            borrower,
            collateralReserve,
            loanReserve,
            loanAmount
        );
        userProxyCall(abiEncoding, reputationAddress, liquidateAction, loanReserve, loanAmount);
    }

    /// @notice Function that packs the call to the `liquidate` function in `SimpleLending` as an abi enconding and then calls 
    /// the `msg.sender`'s `UserProxy` to call `SimpleLending` with the abi encoding
    /// @param borrower Addres of user to liquidate
    /// @param collateralReserve Collateral reserve belonging to `borrower` to be paid back in as a result of the liquidation
    /// @param loanReserve Addres of loan asset to liquidate in `SimpleLending`
    /// @param loanAmount Quantity of `reserve` to liquidate from `SimpleLending`
    function liquidate(address borrower, address collateralReserve, address loanReserve, uint256 loanAmount) public {
        bytes memory abiEncoding = abi.encodeWithSignature(
            "liquidate(address,address,address,uint256)",
            borrower,
            collateralReserve,
            loanReserve,
            loanAmount
        );
        userProxyCall(abiEncoding, msg.sender, liquidateAction, loanReserve, loanAmount);
    }

    function redeemPrivately(
        address reputationAddress, 
        bytes32 firstNewHashValue, 
        bytes32 secondNewHashValue, 
        bytes32[] memory proof,
        address reserve,
        uint256 amount
    ) public {
        bool isIdentityProofValid = IZkIdentity(zkIdentityAddress).proveIdentity(reputationAddress, firstNewHashValue, secondNewHashValue, proof);
        require(isIdentityProofValid, "invalid identity proof");

        bytes memory abiEncoding = abi.encodeWithSignature(
            "redeem(address,uint256)",
            reserve,
            amount
        );
        userProxyCall(abiEncoding, reputationAddress, redeemAction);
    }

    /// @notice Function that packs the call to the `redeem` function in `SimpleLending` as an abi enconding and then calls 
    /// the `msg.sender`'s `UserProxy` to call `SimpleLending` with the abi encoding
    /// @param reserve Addres of asset to redeem deposited funds from `SimpleLending`
    /// @param amount Quantity of `reserve` to redeem deposited funds from `SimpleLending`
    function redeem(address reserve, uint256 amount) public {
        bytes memory abiEncoding = abi.encodeWithSignature(
            "redeem(address,uint256)",
            reserve,
            amount
        );
        userProxyCall(abiEncoding, msg.sender, redeemAction);
    }

}

