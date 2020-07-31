pragma solidity ^0.5.0;


import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@nomiclabs/buidler/console.sol";
import "../IWebOfTrust.sol";


contract SimpleLending is Ownable {
    mapping (address => mapping(address => uint)) userDeposits;
    mapping (address => mapping(address => uint)) userLoans;
    mapping(address => uint) reserveLiquidity;
    address webOfTrustAddress;
    address[] reserves;
    uint baseCollateralisationRate;
    uint baseCollateralisationRateDecimals;

    address ethAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 collateralizationDecimals = 3; // decimals to calculate collateral factor
    uint conversionDecimals = 25;

    constructor(
        address payable webOfTrustAddressValue,
        uint baseCollateralisationRateValue,
        uint baseCollateralisationRateDecimalsValue
    ) public {
        baseCollateralisationRate = baseCollateralisationRateValue;
        baseCollateralisationRateDecimals = baseCollateralisationRateDecimalsValue;
        webOfTrustAddress = webOfTrustAddressValue;
        reserves.push(ethAddress);
    }

    function() external payable {
        console.log("in SimpleLending fallback");
    }

    function setBaseCollateralisationRate(uint baseCollateralisationRateValue) external onlyOwner {
        baseCollateralisationRate = baseCollateralisationRateValue;
    }

    function getBaseCollateralisationRate() external view returns (uint) {
        return baseCollateralisationRate;
    }

    function addReserve(address newReserve) public {
        reserves.push(newReserve);
    }

    function deposit(address reserve, uint256 amount) public payable {
        if(reserve == ethAddress) {
            require(msg.value == amount, "amount is different from msg.value");
        } else {
            IERC20(reserve).transferFrom(msg.sender, address(this), amount);
        }
        userDeposits[msg.sender][reserve] += amount;
        reserveLiquidity[reserve] += amount;
    }

    function borrow(address reserve, uint256 amount) public {
        require(hasEnoughCollateral(reserve, amount), "too little collateral");
        require(reserveLiquidity[reserve] >= amount, "not enough reserve liquidity");
        makePayment(reserve, amount, msg.sender);
        userLoans[msg.sender][reserve] += amount;
    }

    function repay(address reserve, uint256 amount, address onBehalf) public payable {
        require(userLoans[onBehalf][reserve] >= amount, "amount is larger than actual borrow");
        if(reserve == ethAddress) {
            require(msg.value == amount, "amount is different from msg.value");
        } else {
            IERC20(reserve).transferFrom(msg.sender, address(this), amount);
        }
        userLoans[onBehalf][reserve] -= amount;
        reserveLiquidity[reserve] += amount;
    }

    function liquidate(address borrower, address collateralReserve, address loanReserve, uint256 loanAmount) public payable {
        require(
            getMaxAmountToLiquidateInReserve(borrower, loanReserve) > 0,
            "The account is already properly collateralized or the liquidation amount is larger than borrower loan"
        );
        if(loanReserve == ethAddress) {
            require(msg.value == loanAmount, "Amount is different from msg.value");
        } else {
            IERC20(loanReserve).transferFrom(msg.sender, address(this), loanAmount);
        }
        (uint returnedCollateralAmount, ) = convert(loanReserve, collateralReserve, loanAmount);
        returnedCollateralAmount = applyLiquidationDiscount(returnedCollateralAmount);
        returnedCollateralAmount = divideByConversionDecimals(returnedCollateralAmount);

        userLoans[borrower][loanReserve] -= loanAmount;
        userDeposits[borrower][collateralReserve] -= returnedCollateralAmount;
        makePayment(collateralReserve, returnedCollateralAmount, msg.sender);
        reserveLiquidity[loanReserve] += loanAmount;
        reserveLiquidity[collateralReserve] -= returnedCollateralAmount;
    }

    function redeem(address reserve, uint256 amount) public {
        require(!isUnderCollateralised(msg.sender), "agent would become undercollateralized after redeem");
        uint userLiquidity = userDeposits[msg.sender][reserve] - userLoans[msg.sender][reserve];
        require(userLiquidity > 0, "You don't have enough liquidity in this reserve");
        makePayment(reserve, amount, msg.sender);
        userDeposits[msg.sender][reserve] -= amount;
    }

    function makePayment(address reserve, uint256 amount, address payable payee) internal enoughLiquidity(reserve, amount) {
        if(reserve == ethAddress) {
            payee.transfer(amount);
        } else {
            IERC20(reserve).transfer(payee, amount);
        }
        reserveLiquidity[reserve] -= amount;
    }

    function hasEnoughCollateral(address reserve, uint256 amount) public returns (bool) {
        (uint borrowableAmountInETH, ) = getBorrowableAmountInETH(msg.sender);
        (uint loanWorthInETH, ) = convert(reserve, ethAddress, amount);
        return borrowableAmountInETH >= loanWorthInETH;
    }

    modifier enoughLiquidity(address reserve, uint256 amount) {
        require(reserveLiquidity[reserve] >= amount, "not enough reserve liquidity");
        _;
    }

    function getUserDepositsInETH(address account) public view returns (uint, uint) {
        uint deposits = 0;
        for(uint i = 0; i < reserves.length; i++) {
            (uint conversion, ) = convert(reserves[i], ethAddress, userDeposits[account][reserves[i]]);
            deposits += conversion;
        }
        return (deposits, conversionDecimals);
    }

    function getUserDepositToReserve(address account, address reserve) public view returns (uint) {
        return userDeposits[account][reserve];
    }

    function getUserLoansInETH(address account) public view returns (uint, uint) {
        uint borrows = 0;
        for(uint i = 0; i < reserves.length; i++) {
            (uint conversion, ) = convert(reserves[i], ethAddress, userLoans[account][reserves[i]]);
            borrows += conversion;
        }
        return (borrows, conversionDecimals);
    }

    function getUserLoansFromReserve(address account, address reserve) public view returns (uint) {
        return userLoans[account][reserve];
    }

    function getBorrowableAmountInETH(address account) public returns (uint, uint) {
        (uint deposits, ) = getUserDepositsInETH(account);
        (uint borrows, ) = getUserLoansInETH(account);
        uint accountCollateralizationRatio = baseCollateralisationRate * IWebOfTrust(webOfTrustAddress).getAggregateAgentFactorForProtocol(account, address(this));
        uint collateral = (deposits / accountCollateralizationRatio) * (10 ** (baseCollateralisationRateDecimals + IWebOfTrust(webOfTrustAddress).getAgentFactorDecimals()));
        require(!isUnderCollateralised(account), "agent is undercollateralized");
        uint borrowableAmountInETH = collateral - borrows;
        console.log("borrowableAmountInETH *(10**25):");
        console.log(borrowableAmountInETH / (10**(conversionDecimals)));
        return (borrowableAmountInETH, conversionDecimals);
    }

    function isUnderCollateralised(address account) public view returns (bool) {
        (uint collateralInUse, ) = getCollateralInUseInETH(account);
        (uint deposits, ) = getUserDepositsInETH(account);
        return deposits < collateralInUse;
    }

    function getMaxAmountToLiquidateInReserve(address account, address reserve) public view returns (uint) {
        require(isUnderCollateralised(account), "Account is not undercollateralised");
        (uint collateralInUse, ) = getCollateralInUseInETH(account);
        (uint deposits, ) = getUserDepositsInETH(account);

        uint maxAmountToLiquidateInEth = (collateralInUse - deposits) / (10 ** conversionDecimals);

        (uint maxAmountToLiquidateInReserve, ) = convert(ethAddress, reserve, maxAmountToLiquidateInEth);
        maxAmountToLiquidateInReserve = maxAmountToLiquidateInReserve / (10 ** conversionDecimals);
        maxAmountToLiquidateInReserve = min(maxAmountToLiquidateInReserve, userLoans[account][reserve]);

        return maxAmountToLiquidateInReserve;
    }

    function getCollateralInUseInETH(address account) public view returns (uint, uint) {
        (uint borrows, ) = getUserLoansInETH(account);
        uint accountCollateralizationRatio = baseCollateralisationRate * IWebOfTrust(webOfTrustAddress).getAggregateAgentFactorForProtocol(account, address(this));
        uint collateralInUse = (borrows * accountCollateralizationRatio) / (10 ** (baseCollateralisationRateDecimals + IWebOfTrust(webOfTrustAddress).getAgentFactorDecimals()));
        return (collateralInUse, conversionDecimals);
    }


    function conversionRate(address fromReserve, address toReserve) public view returns (uint, uint) {
        uint from = reserveLiquidity[fromReserve];
        uint to = reserveLiquidity[toReserve];

        if (from == 0 || to == 0) {
            // if there's no liquidity, the price is "infinity"
            return  (2**100, 0);
        }
        
        uint conversion = to * (10 ** conversionDecimals) / from;
        return (conversion, conversionDecimals);
    }

    function convert(address fromReserve, address toReserve, uint amount) public view returns (uint, uint) {
        (uint conversionRate, uint decimals) = conversionRate(fromReserve, toReserve);
        return (amount * conversionRate, decimals);
    }

    function divideByConversionDecimals(uint x) public returns (uint) {
        return x / (10 ** conversionDecimals);
    }

    function applyLiquidationDiscount(uint sum) internal returns (uint) {
        return sum * 10 / 9;
    }

    function min(uint a, uint b) private pure returns (uint) {
        return a < b ? a : b;
    }

}
