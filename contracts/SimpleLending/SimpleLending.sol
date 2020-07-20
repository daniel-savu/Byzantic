pragma solidity ^0.5.0;


import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@nomiclabs/buidler/console.sol";
import "../WebOfTrust.sol";



contract SimpleLending is Ownable {
    mapping (address => mapping(address => uint)) userDeposits;
    mapping (address => mapping(address => uint)) userLoans;
    mapping(address => uint) reserveLiquidity;
    address[] reserves;
    uint baseCollateralisationRate;
    WebOfTrust webOfTrust;
    address ethAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 collateralizationDecimals = 3; // decimals to calculate collateral factor
    uint conversionDecimals = 25;

    constructor(address payable webOfTrustAddress, uint baseCollateralisationRateValue) public {
        baseCollateralisationRate = baseCollateralisationRateValue;
        webOfTrust = WebOfTrust(webOfTrustAddress);
        reserves.push(ethAddress);
    }

    function() external payable {
        console.log("in SimpleLending fallback");
    }

    function setBaseCollateralisationRate(uint baseCollateralisationRateValue) public onlyOwner {
        baseCollateralisationRate = baseCollateralisationRateValue;
    }

    function getBaseCollateralisationRate() public returns (uint) {
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
        userLoans[msg.sender][reserve] -= amount;
        reserveLiquidity[reserve] += amount;
    }

    function liquidate(address borrower, address collateralReserve, address loanReserve, uint256 loanAmount) public payable {
        // need to retrieve the collateralization ratio of 'account'
        // from the WebOfTrust contract
        // and check whether user is undercollateralized
        (uint deposits, ) = getAccountDeposits(borrower);
        (uint borrows, ) = getAccountBorrows(borrower);
        uint accountCollateralizationRatio = baseCollateralisationRate * webOfTrust.getAggregateAgentFactorForProtocol(borrower, address(this));
        uint availableCollateral = deposits - borrows * accountCollateralizationRatio;
        // deposits and borrows are expressed as numbers multiplied by 10 ** conversionDecimals
        availableCollateral = divideByConversionDecimals(availableCollateral);

        require(availableCollateral < 0, "The account is already properly collateralized");
        require(userLoans[borrower][loanReserve] >= loanAmount, "amount is larger than actual loan");
        if(loanReserve == ethAddress) {
            require(msg.value == loanAmount, "amount is different from msg.value");
        } else {
            IERC20(loanReserve).transferFrom(msg.sender, address(this), loanAmount);
        }
        userLoans[borrower][loanReserve] -= loanAmount;
        (uint returnedCollateralAmount, ) = convert(loanReserve, collateralReserve, loanAmount);
        returnedCollateralAmount = divideByConversionDecimals(returnedCollateralAmount);

        userDeposits[borrower][collateralReserve] -= returnedCollateralAmount;
        makePayment(collateralReserve, loanAmount, msg.sender);
        reserveLiquidity[loanReserve] += loanAmount;
        reserveLiquidity[collateralReserve] -= returnedCollateralAmount;
    }

    function redeem(address reserve, uint256 amount) public {
        (uint collateralInUse, ) = getCollateralInUse(msg.sender);
        (uint deposits, ) = getAccountDeposits(msg.sender);
        require(deposits >= collateralInUse, "agent would become undercollateralized after redeem");
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
        borrowableAmountInETH = divideByConversionDecimals(borrowableAmountInETH);
        uint loanWorthInETH;
        if(reserve == ethAddress) {
            loanWorthInETH = amount;
        } else {
            (loanWorthInETH, ) = convert(ethAddress, reserve, amount);
            loanWorthInETH = divideByConversionDecimals(loanWorthInETH);
        }
        return borrowableAmountInETH >= loanWorthInETH;
    }

    modifier enoughLiquidity(address reserve, uint256 amount) {
        require(reserveLiquidity[reserve] >= amount, "not enough reserve liquidity");
        _;
    }

    function getAccountDeposits(address account) public view returns (uint, uint) {
        uint deposits = 0;
        for(uint i = 0; i < reserves.length; i++) {
            (uint conversion, ) = convert(reserves[i], ethAddress, userDeposits[account][reserves[i]]);
            deposits += conversion;
        }
        return (deposits, conversionDecimals);
    }

    function getAccountBorrows(address account) public view returns (uint, uint) {
        uint borrows = 0;
        for(uint i = 0; i < reserves.length; i++) {
            (uint conversion, ) = convert(reserves[i], ethAddress, userLoans[account][reserves[i]]);
            borrows += conversion;
        }
        return (borrows, conversionDecimals);
    }

    function getBorrowableAmountInETH(address account) public returns (uint, uint) {
        console.log("in getBorrowableAmountInETH");
        (uint deposits, ) = getAccountDeposits(account);
        (uint borrows, ) = getAccountBorrows(account);
        uint accountCollateralizationRatio = baseCollateralisationRate * webOfTrust.getAggregateAgentFactorForProtocol(account, address(this));
        uint borrowableAmountInETH = (deposits / accountCollateralizationRatio) - borrows;
        console.log("borrowableAmountInETH *(10^25):");
        console.log(borrowableAmountInETH);
        return (borrowableAmountInETH, conversionDecimals);
    }

    function getCollateralInUse(address account) public returns (uint, uint) {
        (uint deposits, ) = getAccountDeposits(account);
        (uint borrows, ) = getAccountBorrows(account);
        uint accountCollateralizationRatio = baseCollateralisationRate * webOfTrust.getAggregateAgentFactorForProtocol(account, address(this));
        uint collateralInUse = deposits - (borrows * accountCollateralizationRatio);
        return (collateralInUse, conversionDecimals);
    }

    function conversionRate(address fromReserve, address toReserve) public view returns (uint, uint) {
        if (reserveLiquidity[fromReserve] == 0 || reserveLiquidity[toReserve] == 0) {
            // if there's no liquidity, the price is "infinity"
            return  (2**100, 0);
        }
        uint from = reserveLiquidity[fromReserve];
        uint to = reserveLiquidity[toReserve];
        if(toReserve == ethAddress) {
            to = to / (10 ** 18);
        }
        uint conversion = from * (10 ** conversionDecimals) / to;
        if(fromReserve == ethAddress) {
            conversion = conversion / (10 ** 18);
        }
        return (conversion, conversionDecimals);
    }

    function convert(address fromReserve, address toReserve, uint amount) public view returns (uint, uint) {
        (uint conversionRate, uint decimals) = conversionRate(fromReserve, toReserve);
        return (amount * conversionRate, decimals);
    }

    function divideByConversionDecimals(uint x) public returns (uint) {
        return x / (10 ** conversionDecimals);
    }

}
// 2000000000000000000
// 5856515373352855