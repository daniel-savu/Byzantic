import env = require("@nomiclabs/buidler");
import CEtherABI from "./ABIs/CEther.json";
import DaiTokenABI from "./ABIs/DAItoken.json";
import LendingPoolAddressesProviderABI from "./ABIs/LendingPoolAddressesProvider.json";
import LendingPoolABI from "./ABIs/LendingPool.json";
import ATokenABI from "./ABIs/AToken.json"
import { assert } from "console";
import { BigNumber } from "ethers/utils";


var web3 = env.web3;
var artifacts = env.artifacts;
var contract = env.contract;

const fs = require('fs');

const WebOfTrust = artifacts.require("WebOfTrust");
const SimpleLendingProxy = artifacts.require("SimpleLendingProxy");
const UserProxyFactory = artifacts.require("UserProxyFactory");
const UserProxy = artifacts.require("UserProxy");
const LBCR = artifacts.require("LBCR");
const SimpleLending = artifacts.require("SimpleLending");
const DaiMock = artifacts.require("DaiMock");
const ZkIdentity = artifacts.require("ZkIdentity");
const Verifier = artifacts.require("Verifier");

// const AaveCollateralManager = artifacts.require("AaveCollateralManager");

const privateKey = "01ad2f5ee476f3559b0d2eb8ec22968e847f0dcf3e1fc7ec02e57ecce5000548";
web3.eth.accounts.wallet.add('0x' + privateKey);
const myWalletAddress = web3.eth.accounts.wallet[0].address;

const ethAddress = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'
const ethAmountInWei = web3.utils.toWei('1', 'ether')
const aETHToken = '0x3a3A65aAb0dd2A17E3F1947bA16138cd37d08c04'
const aETHContract = new web3.eth.Contract(ATokenABI, aETHToken)

const daiAddress = '0x6B175474E89094C44Da98b954EedeAC495271d0F' // mainnet
const daiAmount = '1'

let webOfTrust: typeof WebOfTrust
let userProxyFactory: typeof UserProxyFactory
let accs: typeof WebOfTrust

let simpleLending: typeof SimpleLending
let simpleLendingLBCR: typeof LBCR
let simpleLendingProxy: typeof WebOfTrust

let simpleLendingTwo: typeof SimpleLending
let simpleLendingTwoLBCR: typeof SimpleLending
let simpleLendingTwoProxy: typeof WebOfTrust

let daiMock: typeof WebOfTrust
let zkIdentity: typeof ZkIdentity
let verifier: typeof Verifier;


contract("SimpleLending Protocol", accounts => {

    async function initializeSimpleLendingLBCR(webOfTrust: typeof WebOfTrust) {
        const simpleLendingLBCRAddress = await webOfTrust.getProtocolLBCR(simpleLending.address);
        let simpleLendingLayers = [1, 2, 3, 4, 5];
        // we are using 3 decimals. Thus, 800 means 0.8 collateral
        let simpleLendingLayerFactors = [1000, 900, 850, 800, 750]; 
        let simpleLendingLayerLowerBounds = [0, 20, 40, 60, 80];
        let simpleLendingLayerUpperBounds = [25, 45, 65, 85, 10000];
        await initializeLBCR(simpleLendingLBCRAddress, simpleLendingLayers, simpleLendingLayerFactors, simpleLendingLayerLowerBounds, simpleLendingLayerUpperBounds);
        let lbcr = await LBCR.at(simpleLendingLBCRAddress);
        lbcr.setCompatibilityScoreWith(simpleLendingTwo.address, 50);
        lbcr.upgradeVersion();
    }

    async function initializeSimpleLendingTwoLBCR(webOfTrust: typeof WebOfTrust) {
        const simpleLendingLBCRAddress = await webOfTrust.getProtocolLBCR(simpleLendingTwo.address);
        let simpleLendingLayers = [1, 2, 3, 4, 5];
        let simpleLendingLayerFactors = [1000, 900, 850, 800, 750];
        let simpleLendingLayerLowerBounds = [0, 20, 40, 60, 80];
        let simpleLendingLayerUpperBounds = [25, 45, 65, 85, 10000];
        await initializeLBCR(simpleLendingLBCRAddress, simpleLendingLayers, simpleLendingLayerFactors, simpleLendingLayerLowerBounds, simpleLendingLayerUpperBounds);
        let lbcr = await LBCR.at(simpleLendingLBCRAddress);
        lbcr.setCompatibilityScoreWith(simpleLending.address, 50);
        lbcr.upgradeVersion();
    }

    async function initializeLBCR(LBCRAddress: string, layers: number[], layerFactors: number[], layerLowerBounds: number[], layerUpperBounds: number[]) {
        const lbcr = await LBCR.at(LBCRAddress)
        await lbcr.resetLayers();
        for(let i = 0; i < layers.length; i++) {
            await lbcr.addLayer(layers[i]);
        }
        for(let i = 0; i < layers.length; i++) {
            await lbcr.setFactor(layers[i], layerFactors[i]);
        }
        for(let i = 0; i < layers.length; i++) {
            await lbcr.setBounds(layers[i], layerLowerBounds[i], layerUpperBounds[i]);
        }

        // setting the reward for each action
        // ideally, the reward depends on call parameters
        // Mapping of actions to their id:
        const depositAction = 1;
        const borrowAction = 2;
        const repayAction = 3;
        const liquidationCallAction = 4;
        const flashLoanAction = 5;
        const redeemAction = 6;
        await lbcr.setReward(depositAction, 15);
        await lbcr.setReward(borrowAction, 0);
        await lbcr.setReward(repayAction, 5);
        await lbcr.setReward(liquidationCallAction, 10);
        await lbcr.setReward(flashLoanAction, 10);
        await lbcr.setReward(redeemAction, 0);
    }

    async function initializeLendingProtocol(protocolAddress: string) {
        if(protocolAddress == simpleLending.address) {
            await initializeSimpleLendingLBCR(webOfTrust);
        } else {
            await initializeSimpleLendingTwoLBCR(webOfTrust);
        }
        let lendingProtocol = await SimpleLending.at(protocolAddress);
        lendingProtocol.addReserve(daiMock.address);

        // generating 3 ETH worth of Dai at price 228 Dai per ETH
        await daiMock.mint(accs[1], 684);

        await daiMock.approve(
            lendingProtocol.address,
            684,
            {
                from: accs[1],
            }
        );
        await lendingProtocol.deposit(
            daiMock.address,
            684,
            {
                from: accs[1],
            }
        );

        await lendingProtocol.deposit(
            ethAddress,
            web3.utils.toWei('2', 'ether'),
            {
                from: accs[1],
                value: web3.utils.toHex(web3.utils.toWei('2', 'ether'))
            }
        );
    }

    function divideByConversionDecimals(obj: {0: number, 1: number}) {
        return (obj[0] / (10 ** obj[1]))
    }

    // async function deposit

    before(async function() {
        accs = await web3.eth.getAccounts();
        webOfTrust = await WebOfTrust.new();
        daiMock = await DaiMock.new();

        verifier = await Verifier.new();
        zkIdentity = await ZkIdentity.new(verifier.address);

        let baseCollateralisationRateValue = 1500;
        let baseCollateralisationRateDecimals = 3;
        let userProxyFactoryAddress = await webOfTrust.getUserProxyFactoryAddress();
        userProxyFactory = await UserProxyFactory.at(userProxyFactoryAddress);
        simpleLending = await SimpleLending.new(webOfTrust.address, baseCollateralisationRateValue, baseCollateralisationRateDecimals);
        simpleLendingTwo = await SimpleLending.new(webOfTrust.address, baseCollateralisationRateValue, baseCollateralisationRateDecimals);

        simpleLendingProxy = await SimpleLendingProxy.new(webOfTrust.address, userProxyFactoryAddress, simpleLending.address, zkIdentity.address);
        await webOfTrust.addProtocolIntegration(simpleLending.address, simpleLendingProxy.address);
        await initializeLendingProtocol(simpleLending.address);

        simpleLendingTwoProxy = await SimpleLendingProxy.new(webOfTrust.address, userProxyFactoryAddress, simpleLendingTwo.address, zkIdentity.address);
        await webOfTrust.addProtocolIntegration(simpleLendingTwo.address, simpleLendingTwoProxy.address);
        await initializeLendingProtocol(simpleLendingTwo.address);

        await webOfTrust.registerAgent();


        // let daiMocks = await daiMock.balanceOf(simpleLending.address)
        // console.log(`daiMock balance in SL: ${daiMocks}`);

        let conversionRate = await simpleLending.conversionRate(ethAddress, daiMock.address);
        console.log(`(conversion rate from eth to daiMock: ${divideByConversionDecimals(conversionRate)})`);

        // let conversionValue = await simpleLending.convert(daiMock.address, ethAddress, 684);
        // console.log(`converting 684 from daiMock to eth: ${conversionValue}`);

        // let userSimpleLendingBalance = await simpleLending.getAccountDeposits(accs[1]);
        // console.log(`Account balance in SimpleLending: ${userSimpleLendingBalance}`)
    });

    xit("Should deposit to SimpleLending using interfaces", async function () {
        // assume address is hardcoded
        let webOfTrustAddress = webOfTrust.address;
        // assume abi is hardcoded too
        let webOfTrustAbi = webOfTrust.abi;

        let webOfTrustContract = new web3.eth.Contract(webOfTrustAbi, webOfTrustAddress);

        // assume userProxyFactory address is hardcoded
        let userProxyFactoryAddress = await webOfTrustContract.getUserProxyFactoryAddress();

        // assume userProxyFactory abi is hardcoded
        let userProxyFactoryAbi = userProxyFactory.abi;

        let baseCollateralisationRateValue = 1500;
        let baseCollateralisationRateDecimals = 3;

        simpleLending = await SimpleLending.new(webOfTrust.address, baseCollateralisationRateValue, baseCollateralisationRateDecimals, zkIdentity.address);
        simpleLendingProxy = await SimpleLendingProxy.new(webOfTrust.address, userProxyFactoryAddress, simpleLending.address, zkIdentity.address);
        await webOfTrust.addProtocolIntegration(simpleLending.address, simpleLendingProxy.address);
        await initializeLendingProtocol(simpleLending.address);

        await webOfTrust.registerAgent();

        const userProxyAddress = await userProxyFactory.getUserProxyAddress(accs[0]);

        // assume userProxy abi is available
        const userProxyAbi = UserProxy.abi;

        let userProxyContract = new web3.eth.Contract(userProxyAbi, userProxyAddress);

        let tr = await userProxyContract.depositFunds(
            ethAddress,
            web3.utils.toWei('2', 'ether'),
            {
                value: web3.utils.toHex(web3.utils.toWei('2', 'ether'))
            }
        );

        tr = await simpleLendingProxy.deposit(
            ethAddress,
            web3.utils.toWei('1', 'ether')
        );


    });

    xit("Should deposit to SimpleLending", async function () {
        const userProxyAddress = await userProxyFactory.getUserProxyAddress(accs[0]);
        const userProxy = await UserProxy.at(userProxyAddress);
        let tr = await userProxy.depositFunds(
            ethAddress,
            web3.utils.toWei('2', 'ether'),
            {
                from: accs[0],
                value: web3.utils.toHex(web3.utils.toWei('2', 'ether'))
            }
        );

        console.log("The base collateralization ratio in SimpleLending is 150%");
        // await webOfTrust.getAggregateAgentFactor(userProxy.address); //prints to console in buidler
        
        tr = await simpleLendingProxy.deposit(
            ethAddress,
            web3.utils.toWei('1', 'ether')
        );
        console.log("Deposited 1 Ether in SimpleLending")

        tr = await simpleLendingProxy.deposit(
            ethAddress,
            web3.utils.toWei('1', 'ether')
        );
        console.log("Deposited 1 Ether in SimpleLending")
        await simpleLending.getBorrowableAmountInETH(userProxy.address); //prints to console in buidler
        console.log("gotBorrowableAmountInETH");

        // const agentScore = await simpleLendingLBCR.getScore(userProxy.address);
        // console.log(`the score of the agent in Byzantic (before round end): ${agentScore}`);
        console.log("Ending round. User wil be promoted to a higher layer.");
        await webOfTrust.curateLBCRs();
        // await webOfTrust.getAggregateAgentFactor(userProxy.address); //prints to console in buidler
        await simpleLending.getBorrowableAmountInETH(userProxy.address); //prints to console in buidler

        let conversionRate = await simpleLending.conversionRate(daiMock.address, ethAddress);
        console.log(`(conversion rate from daiMock to eth: ${conversionRate})`);
    });

    xit("Should deposit to, borrow from and repay to SimpleLending", async function () {
        const userProxyAddress = await userProxyFactory.getUserProxyAddress(accs[0]);
        const userProxy = await UserProxy.at(userProxyAddress);
        let tr = await userProxy.depositFunds(
            ethAddress,
            web3.utils.toWei('2', 'ether'),
            {
                from: accs[0],
                value: web3.utils.toHex(web3.utils.toWei('2', 'ether'))
            }
        );

        console.log("The base collateralization ratio in SimpleLending is 150%");
        // await webOfTrust.getAggregateAgentFactor(userProxy.address); //prints to console in buidler
        
        tr = await simpleLendingProxy.deposit(
            ethAddress,
            web3.utils.toWei('1', 'ether')
        );
        console.log("Deposited 1 Ether in SimpleLending")

        tr = await simpleLendingProxy.deposit(
            ethAddress,
            web3.utils.toWei('1', 'ether')
        );
        console.log("Deposited 1 Ether in SimpleLending")
        await simpleLending.getBorrowableAmountInETH(userProxy.address); //prints to console in buidler

        // const agentScore = await simpleLendingLBCR.getScore(userProxy.address);
        // console.log(`the score of the agent in Byzantic (before round end): ${agentScore}`);
        console.log("Ending round. User wil be promoted to a higher layer.");
        await webOfTrust.curateLBCRs();
        await simpleLending.getBorrowableAmountInETH(userProxy.address); //prints to console in buidler

        let conversionRate = await simpleLending.conversionRate(daiMock.address, ethAddress);
        console.log(`(conversion rate from DaiMock to eth: ${divideByConversionDecimals(conversionRate)})`);

        tr = await simpleLendingProxy.borrow(
            daiMock.address,
            "1"
        );
        console.log("Borrowed 1 DaiMock");

        let userSimpleLendingBorrows = await simpleLending.getUserLoansInETH(userProxy.address);
        console.log(`User borrows in SimpleLending (in ETH):   ${divideByConversionDecimals(userSimpleLendingBorrows)}`)

        tr = await simpleLendingProxy.repay(
            daiMock.address,
            "1",
            userProxy.address
        );
        console.log("Repaid loan of 1 DaiMock");

        conversionRate = await simpleLending.conversionRate(ethAddress, daiMock.address);
        console.log(`(conversion rate from ETH to DaiMock: ${divideByConversionDecimals(conversionRate)})`);

        conversionRate = await simpleLending.convert(daiMock.address, ethAddress, "1");
        console.log(`(conversion rate from DaiMock to ETH: ${divideByConversionDecimals(conversionRate)})`);

        userSimpleLendingBorrows = await simpleLending.getUserLoansInETH(userProxy.address);
        console.log(`User borrows in SimpleLending (in ETH):   ${divideByConversionDecimals(userSimpleLendingBorrows)}`)

        tr = await simpleLendingProxy.redeem(
            ethAddress,
            web3.utils.toWei('1', 'ether')
        );
        console.log("Redeemed 1 ETH");

        await userProxy.withdrawFunds(ethAddress, web3.utils.toWei('1', 'ether'));
        console.log("Withdrew 1 ETH from Byzantic");

        let ethBalanceLeftInUserProxy = await userProxy.getReserveBalance(
            ethAddress
        );

        console.log(`ethBalanceLeftInUserProxy: ${ethBalanceLeftInUserProxy}`);
    });
    
    xit("Should deposit to, borrow from and be liquidated by SimpleLending", async function () {
        const userProxyAddress = await userProxyFactory.getUserProxyAddress(accs[0]);
        const userProxy = await UserProxy.at(userProxyAddress);
        let tr = await userProxy.depositFunds(
            ethAddress,
            web3.utils.toWei('2', 'ether'),
            {
                from: accs[0],
                value: web3.utils.toHex(web3.utils.toWei('2', 'ether'))
            }
        );

        console.log("The base collateralization ratio in SimpleLending is 150%");
        // await webOfTrust.getAggregateAgentFactor(userProxy.address); //prints to console in buidler
        
        tr = await simpleLendingProxy.deposit(
            ethAddress,
            web3.utils.toWei('1', 'ether')
        );
        console.log("Deposited 1 Ether in SimpleLending")

        tr = await simpleLendingProxy.deposit(
            ethAddress,
            web3.utils.toWei('1', 'ether')
        );
        console.log("Deposited 1 Ether in SimpleLending")
        await simpleLending.getBorrowableAmountInETH(userProxy.address); //prints to console in buidler

        // const agentScore = await simpleLendingLBCR.getScore(userProxy.address);
        // console.log(`the score of the agent in Byzantic (before round end): ${agentScore}`);
        console.log("Ending round. User wil be promoted to a higher layer.");
        await webOfTrust.curateLBCRs();
        await simpleLending.getBorrowableAmountInETH(userProxy.address); //prints to console in buidler

        let conversionRate = await simpleLending.conversionRate(daiMock.address, ethAddress);
        console.log(`(conversion rate from DaiMock to ETH: ${divideByConversionDecimals(conversionRate)})`);


        conversionRate = await simpleLending.conversionRate(ethAddress, daiMock.address);
        console.log(`(conversion rate from ETH to DaiMock: ${divideByConversionDecimals(conversionRate) * (10**18)})`);

        let userSimpleLendingBorrows = await simpleLending.getUserLoansInETH(userProxy.address);
        console.log(`User borrows in SimpleLending (in ETH):   ${divideByConversionDecimals(userSimpleLendingBorrows)}`)

        tr = await simpleLendingProxy.borrow(
            daiMock.address,
            "150"
        );
        console.log("Borrowed 150 DaiMock");
        await simpleLending.getBorrowableAmountInETH(userProxy.address); //prints to console in buidler


        let redeemedDaiMock = 300;

        await simpleLending.redeem(
            daiMock.address,
            redeemedDaiMock,
            {
                from: accs[1],
            }
        );

        console.log(`Redeemed ${redeemedDaiMock} DaiMock from different account`);
        let underCollateralised = await simpleLending.isUnderCollateralised(userProxy.address);
        console.log(`agent undercollateralised: ${underCollateralised}`);

        let maxAmountToLiquidate = await simpleLending.getMaxAmountToLiquidateInReserve(userProxy.address, daiMock.address);
        console.log(`maxAmountToLiquidate: ${maxAmountToLiquidate}`);

        // the real max amount to liquidate is 51 rather than 98 because there is very little liquidity
        let daiAmountToLiquidate = 51
        await daiMock.mint(accs[1], daiAmountToLiquidate);

        await daiMock.approve(
            simpleLending.address,
            daiAmountToLiquidate,
            {
                from: accs[1],
            }
        );

        await simpleLending.liquidate(
            userProxy.address,
            ethAddress,
            daiMock.address,
            daiAmountToLiquidate,
            {
                from: accs[1],
            }
        );
    });


    xit("Should deposit to, borrow from and be liquidated by SimpleLending through Byzantic", async function () {
        await webOfTrust.registerAgent({
            from: accs[1],
        });
        const liquidatorUserProxyAddress = await userProxyFactory.getUserProxyAddress(accs[1]);
        const liquidatorUserProxy = await UserProxy.at(liquidatorUserProxyAddress);

        await liquidatorUserProxy.depositFunds(
            ethAddress,
            web3.utils.toWei('5', 'ether'),
            {
                from: accs[1],
                value: web3.utils.toHex(web3.utils.toWei('5', 'ether'))
            }
        );


        const userProxyAddress = await userProxyFactory.getUserProxyAddress(accs[0]);
        const userProxy = await UserProxy.at(userProxyAddress);
        let tr = await userProxy.depositFunds(
            ethAddress,
            web3.utils.toWei('2', 'ether'),
            {
                from: accs[0],
                value: web3.utils.toHex(web3.utils.toWei('2', 'ether'))
            }
        );

        console.log("The base collateralization ratio in SimpleLending is 150%");
        // await webOfTrust.getAggregateAgentFactor(userProxy.address); //prints to console in buidler
        
        tr = await simpleLendingProxy.deposit(
            ethAddress,
            web3.utils.toWei('1', 'ether')
        );
        console.log("Deposited 1 Ether in SimpleLending")

        tr = await simpleLendingProxy.deposit(
            ethAddress,
            web3.utils.toWei('1', 'ether')
        );
        console.log("Deposited 1 Ether in SimpleLending")
        await simpleLending.getBorrowableAmountInETH(userProxy.address); //prints to console in buidler

        // const agentScore = await simpleLendingLBCR.getScore(userProxy.address);
        // console.log(`the score of the agent in Byzantic (before round end): ${agentScore}`);
        console.log("Ending round. User wil be promoted to a higher layer.");
        await webOfTrust.curateLBCRs();
        await simpleLending.getBorrowableAmountInETH(userProxy.address); //prints to console in buidler

        let conversionRate = await simpleLending.conversionRate(daiMock.address, ethAddress);
        console.log(`(conversion rate from DaiMock to ETH: ${divideByConversionDecimals(conversionRate)})`);


        conversionRate = await simpleLending.conversionRate(ethAddress, daiMock.address);
        console.log(`(conversion rate from ETH to DaiMock: ${divideByConversionDecimals(conversionRate) * (10**18)})`);

        let userSimpleLendingBorrows = await simpleLending.getUserLoansInETH(userProxy.address);
        console.log(`User borrows in SimpleLending (in ETH):   ${divideByConversionDecimals(userSimpleLendingBorrows)}`)

        tr = await simpleLendingProxy.borrow(
            daiMock.address,
            "10"
        );
        console.log("Borrowed 10 DaiMock");
        await simpleLending.getBorrowableAmountInETH(userProxy.address); //prints to console in buidler


        let redeemedDaiMock = 300;

        tr = await simpleLendingProxy.deposit(
            ethAddress,
            web3.utils.toWei('5', 'ether'),
            {
                from: accs[1],
            }
        );


        console.log(`Deposited 5 ETH from different account to devaluate it`);
        let underCollateralised = await simpleLending.isUnderCollateralised(userProxy.address);
        console.log(`agent undercollateralised: ${underCollateralised}`);

        let maxAmountToLiquidate = await simpleLending.getMaxAmountToLiquidateInReserve(userProxy.address, daiMock.address);
        console.log(`maxAmountToLiquidate: ${maxAmountToLiquidate}`);

        // the real max amount to liquidate is 51 rather than 98 because there is very little liquidity
        let daiAmountToLiquidate = 51
        await daiMock.mint(accs[1], daiAmountToLiquidate);

        await daiMock.approve(
            liquidatorUserProxy.address,
            daiAmountToLiquidate,
            {
                from: accs[1],
            }
        );

        await liquidatorUserProxy.depositFunds(
            daiMock.address,
            daiAmountToLiquidate,
            {
                from: accs[1]
            }
        );

        await simpleLendingProxy.liquidate(
            userProxy.address,
            ethAddress,
            daiMock.address,
            daiAmountToLiquidate,
            {
                from: accs[1],
            }
        );
        
        console.log(`Liquidated : ${daiAmountToLiquidate} DaiMock of debt`);

    });

    xit("Should deposit to SimpleLending and SimpleLendingTwo", async function () {
        const userProxyAddress = await userProxyFactory.getUserProxyAddress(accs[0]);
        const userProxy = await UserProxy.at(userProxyAddress);
        let tr = await userProxy.depositFunds(
            ethAddress,
            web3.utils.toWei('3', 'ether'),
            {
                from: accs[0],
                value: web3.utils.toHex(web3.utils.toWei('3', 'ether'))
            }
        );

        console.log("The base collateralization ratio in SimpleLending is 150%");
        
        tr = await simpleLendingProxy.deposit(
            ethAddress,
            web3.utils.toWei('1', 'ether')
        );
        console.log("Deposited 1 Ether in SimpleLending")

        tr = await simpleLendingProxy.deposit(
            ethAddress,
            web3.utils.toWei('1', 'ether')
        );
        console.log("Deposited 1 Ether in SimpleLending")

        tr = await simpleLendingTwoProxy.deposit(
            ethAddress,
            web3.utils.toWei('1', 'ether')
        );
        console.log("Deposited 1 Ether in SimpleLendingTwo")
        console.log();
        console.log("Borrowable amount in SimpleLending:");
        await simpleLending.getBorrowableAmountInETH(userProxy.address); //prints to console in buidler
        console.log();

        console.log("Borrowable amount in SimpleLendingTwo:");
        await simpleLendingTwo.getBorrowableAmountInETH(userProxy.address); //prints to console in buidler
        console.log();
        
        console.log("Ending round. User wil be promoted to a higher layer in SimpleLending, but not in SimpleLendingTwo.");
        await webOfTrust.curateLBCRs();
        console.log();

        console.log("Borrowable amount in SimpleLending:");
        await simpleLending.getBorrowableAmountInETH(userProxy.address); //prints to console in buidler
        console.log();

        console.log("Borrowable amount in SimpleLendingTwo:");
        await simpleLendingTwo.getBorrowableAmountInETH(userProxy.address); //prints to console in buidler

        let conversionRate = await simpleLending.conversionRate(daiMock.address, ethAddress);
        console.log(`(conversion rate from daiMock to eth: ${divideByConversionDecimals(conversionRate)})`);
    });

    describe('ZkIdentity functionality', async () => {
        const { encodeProof } = require('./encodeProof');
        let firstHash: any;
        let secondHash: any;
        let proofObject: any;

        const rawProof = fs.readFileSync('./zkp/proof.json');
        proofObject = JSON.parse(rawProof);
        (
            { inputs: [firstHash, secondHash] } = proofObject
        );


        it('should perform a privacy-preserving call', async () => {
            await zkIdentity.setReputationAddressAuthentication(firstHash, secondHash);

            const proof = encodeProof(proofObject);

            const userProxyAddress = await userProxyFactory.getUserProxyAddress(accs[0]);
            const userProxy = await UserProxy.at(userProxyAddress);
            let tr = await userProxy.depositFunds(
                ethAddress,
                web3.utils.toWei('2', 'ether'),
                {
                    from: accs[0],
                    value: web3.utils.toHex(web3.utils.toWei('2', 'ether'))
                }
            );
    
            // make a call to SimpleLending from accs[1], but using the reputation of accs[0]
            tr = await simpleLendingProxy.depositPrivately(
                accs[0], //reputation address
                firstHash,
                secondHash,
                proof,
                ethAddress,
                web3.utils.toWei('1', 'ether'),
                {
                    from: accs[1],
                }
            );

            // the userProxy of accs[0] should have sent the deposit to SimpleLending, because accs[1] 
            // proved that it was linked to accs[0] using a zero-knowledge proof
            let totalDepositsAsETH = await simpleLending.getUserDepositToReserve(userProxy.address, ethAddress);
            assert(totalDepositsAsETH.toString() == web3.utils.toWei('1', 'ether').toString());
        });
    });

});

// contract("ByzanticAaveProxy", accounts => {
//     const referralCode = '0'
    // const daiAddress = '0x6B175474E89094C44Da98b954EedeAC495271d0F' // mainnet
    // const daiAmountinWei = web3.utils.toWei("0.1", "ether")
//     const interestRateMode = 2 // variable rate
//     const lpAddressProviderAddress = '0x24a42fD28C976A61Df5D00D0599C34c4f90748c8'
//     const lpAddressProviderContract = new web3.eth.Contract(LendingPoolAddressesProviderABI, lpAddressProviderAddress)

//     xit("Should take an Aave flashloan using Byzantic", async function () {
//         // const FlashLoanExecutor = artifacts.require("FlashLoanExecutor");

//         this.timeout(1000000);
//         const t = await WebOfTrust.new();
//         await t.registerAgent();
//         const taAddress = await t.getByzanticAaveProxy({
//             from: myWalletAddress,
//             gasLimit: web3.utils.toHex(150000),
//             gasPrice: web3.utils.toHex(20000000000),
//         });
//         const ta = await ByzanticAaveProxy.at(taAddress)

//         // const flr = await FlashLoanExecutor.new(lpAddressProviderContract.options.address);
//         // let amount = web3.utils.toWei("100", "ether");
//         // let params = "0x0";

//         // let feeRate = 0.0009;
//         // let fee = Number(amount) * feeRate;

//         // // send enough funds to FlashLoanExecutor to pay the flashloan fee

//         // await web3.eth.sendTransaction({
//         //     from: myWalletAddress,
//         //     to: flr.address,
//         //     value: web3.utils.toHex(fee),
//         //     gasLimit: web3.utils.toHex(150000),
//         //     gasPrice: web3.utils.toHex(20000000000),
//         // });

//         // var balance = await web3.eth.getBalance(flr.address); 
//         // console.log(`Balance before the flashloan (0.09%): ${balance}`);
//         // let tr = await ta.flashLoan(
//         //     flr.address, 
//         //     ethAddress, 
//         //     amount,
//         //     params,
//         //     {
//         //         from: myWalletAddress,
//         //         gasLimit: web3.utils.toHex(1500000000),
//         //         gasPrice: web3.utils.toHex(20000000000),
//         //     }
//         // );
//         // balance = await web3.eth.getBalance(flr.address); 
//         // console.log(`Balance after the flashloan                 : ${balance}`);
//         // console.log(tr)
//         // assert(balance == 0);
//     });

//     xit("Should call Aave from Byzantic", async function () {
//         this.timeout(1000000);

//         // Get the latest LendingPool contract address
//         const lpAddress = await lpAddressProviderContract.methods
//             .getLendingPool()
//             .call()
//             .catch((e: { message: any; }) => {
//                 throw Error(`Error getting lendingPool address: ${e.message}`)
//             })

//         console.log(lpAddress)

//         // Make the deposit transaction via LendingPool contract
//         const lpContract = new web3.eth.Contract(LendingPoolABI, lpAddress)

//         const t = await WebOfTrust.new();
//         await t.registerAgent();
//         const taAddress = await t.getByzanticAaveProxy({
//             from: myWalletAddress,
//             gasLimit: web3.utils.toHex(150000),
//             gasPrice: web3.utils.toHex(20000000000),
//         });
//         const ta = await ByzanticAaveProxy.at(taAddress);

//         const userProxyAddress = await t.getUserProxy(
//             myWalletAddress,
//             {
//                 from: myWalletAddress,
//                 gasLimit: web3.utils.toHex(150000),
//                 gasPrice: web3.utils.toHex(20000000000),
//             }
//         );
//         const userProxy = await UserProxy.at(userProxyAddress);
//         let tr = await userProxy.depositFunds(
//             ethAddress,
//             ethAmountInWei,
//             {
//                 from: myWalletAddress,
//                 gasLimit: web3.utils.toHex(1500000),
//                 gasPrice: web3.utils.toHex(20000000000),
//                 value: web3.utils.toHex(web3.utils.toWei('1', 'ether'))
//             }
//         );

//         console.log("Deposited funds in UserProxy");
//         let balanceAfterDeposit = await web3.eth.getBalance(userProxy.address)
//         console.log(`Balance:                                                    ${balanceAfterDeposit}`)

//         tr = await ta.deposit(
//             ethAddress,
//             ethAmountInWei,
//             referralCode,
//             {
//                 from: myWalletAddress,
//                 gasLimit: web3.utils.toHex(1500000),
//                 gasPrice: web3.utils.toHex(20000000000),
//             }
//         );
//         console.log(tr);
//         console.log("Deposited 1 Ether")

//         let balanceAfterAaveDeposit = await web3.eth.getBalance(userProxy.address)
//         console.log(`Balance left:                                         ${balanceAfterAaveDeposit}`)

//         let ethContractBalance = await aETHContract.methods.balanceOf(userProxy.address).call()
//         console.log(`Balance in the Aave ETH contract: ${ethContractBalance}`)

//         const aaveCollateralManagerAddress = await t.getAaveCollateralManager(
//             {
//                 from: myWalletAddress,
//                 gasLimit: web3.utils.toHex(150000),
//                 gasPrice: web3.utils.toHex(20000000000),
//             }
//         );

//         let aaveCollateralManagerContractBalanceInAToken = await aETHContract.methods.balanceOf(aaveCollateralManagerAddress).call()
//         console.log(`Balance in the Aave ETH contract for CM: ${aaveCollateralManagerContractBalanceInAToken}`)

//         let aaveCollateralManagerContractBalance = await web3.eth.getBalance(aaveCollateralManagerAddress)
//         console.log(`Balance left in CM:                                         ${aaveCollateralManagerContractBalance}`)


//         // Borrowing Dai using the deposited Eth as collateral
//         // tr = await ta.borrow(
//         //         daiAddress,
//         //         daiAmountinWei,
//         //         interestRateMode,
//         //         referralCode,
//         //         {
//         //                 from: myWalletAddress,
//         //                 gasLimit: web3.utils.toHex(1500000),
//         //                 gasPrice: web3.utils.toHex(20000000000)
//         //         }
//         // );
//         // console.log(`Borrowed ${daiAmountinWei} Dai amount in Wei`)
//         // let d = await lpContract.methods.getUserAccountData(userProxy.address).call()
//         // console.log(d);

//         // // // await delay(2000);
//         // console.log(`Paying back ${daiAmountinWei} gwei`)
//         // tr = await ta.repay(
//         //         daiAddress,
//         //         daiAmountinWei,
//         //         myWalletAddress,
//         //         {
//         //                 from: myWalletAddress,
//         //                 gasLimit: web3.utils.toHex(15000000),
//         //                 gasPrice: web3.utils.toHex(200000000000),
//         //         }
//         // );
//         // console.log(tr)
//         // console.log("Repaid the borrow")
//         // // d = await lpContract.methods.getUserAccountData(userProxy.address).call()
//         // // console.log(d);

//         // let balanceBeforeRedeem = await aETHContract.methods.balanceOf(userProxy.address).call()

//         // // account for slippage from borrow repayment
//         // balanceBeforeRedeem = parseInt(balanceBeforeRedeem) - 30000000000000
//         // balanceBeforeRedeem = balanceBeforeRedeem.toString()
//         // console.log(`Redeeming the balance of: ${balanceBeforeRedeem}`)

//         // tr = await ta.redeem(
//         //         aETHToken,
//         //         balanceBeforeRedeem,
//         //         {
//         //                 from: myWalletAddress,
//         //                 gasLimit: web3.utils.toHex(15000000),
//         //                 gasPrice: web3.utils.toHex(200000000000),
//         //         }
//         // );
//         // let balanceAfterRedeem = await aETHContract.methods.balanceOf(userProxy.address).call()
//         // console.log(`Balance left:                         ${balanceAfterRedeem}`)

//         // let balanceInUserProxyAfterRedeem = await web3.eth.getBalance(userProxy.address)
//         // console.log(`Balance in UserProxy:                                         ${balanceInUserProxyAfterRedeem}`)
//         // console.log(tr)
//         // assert(balanceAfterRedeem < balanceBeforeRedeem);


//         // let agentScore = await ta.getAgentScore({
//         //                 from: myWalletAddress,
//         //                 gasLimit: web3.utils.toHex(15000000),
//         //                 gasPrice: web3.utils.toHex(200000000000),
//         //         });
//         // console.log(`Based on the tested actions, the test agent has achieved a score of ${agentScore}. `);
//         // console.log(`Keep performing desired Aave actions to further reduce your collateral!`);

//         // await ta.curate({
//         //         from: myWalletAddress,
//         //         gasLimit: web3.utils.toHex(15000000),
//         //         gasPrice: web3.utils.toHex(200000000000),
//         // });
//     });

//     xit("Should call Aave directly from javascript", async function () {
//         this.timeout(1000000);

//         // Get the latest LendingPool contract address
//         const lpAddress = await lpAddressProviderContract.methods
//             .getLendingPool()
//             .call()
//             .catch((e: { message: any; }) => {
//                 throw Error(`Error getting lendingPool address: ${e.message}`)
//             })

//         // Make the deposit transaction via LendingPool contract
//         const lpContract = new web3.eth.Contract(LendingPoolABI, lpAddress)

//         let tr = await lpContract.methods
//             .deposit(
//                 ethAddress,
//                 ethAmountInWei,
//                 referralCode
//             )
//             .send({
//                 from: myWalletAddress,
//                 gasLimit: web3.utils.toHex(1500000),
//                 gasPrice: web3.utils.toHex(20000000000),
//                 value: web3.utils.toHex(web3.utils.toWei('1', 'ether'))
//             })

//         // console.log(tr)
//         console.log("Deposited 1 Ether")

//         tr = await lpContract.methods
//             .getUserReserveData(ethAddress, myWalletAddress)
//             .call()
//             .catch((e: { message: any; }) => {
//                 throw Error(`Error with getUserReserveData() call to the LendingPool contract: ${e.message}`)
//             })
//         // console.log(tr)

//         // Borrowing Dai using the deposited Eth as collateral

//         // await lpContract.methods
//         // .borrow(
//         //         daiAddress,
//         //         daiAmountinWei,
//         //         interestRateMode,
//         //         referralCode
//         // )
//         // .send({
//         //         from: myWalletAddress,
//         //         gasLimit: web3.utils.toHex(1500000),
//         //         gasPrice: web3.utils.toHex(20000000000)
//         // })


//         // console.log(`Borrowed ${daiAmountinWei} Dai amount in Wei`)

//         // let d = await lpContract.methods.getUserAccountData(myWalletAddress).call()
//         // console.log(d);

//         // console.log(`Paying back ${daiAmountinWei} gwei`)

//         // // Get the latest LendingPoolCore address
//         // const lpCoreAddress = await lpAddressProviderContract.methods
//         //         .getLendingPoolCore()
//         //         .call()

//         // // Approve the LendingPoolCore address with the DAI contract
//         // const daiContract = new web3.eth.Contract(DaiTokenABI, daiAddress)
//         // await daiContract.methods
//         //         .approve(
//         //                 lpCoreAddress,
//         //                 daiAmountinWei
//         //         )
//         //         .send({
//         //                 from: myWalletAddress,
//         //                 gasLimit: web3.utils.toHex(15000000),
//         //                 gasPrice: web3.utils.toHex(200000000000),
//         //         })

//         // await lpContract.methods
//         // .repay(
//         //         daiAddress,
//         //         daiAmountinWei,
//         //         myWalletAddress
//         // )
//         // .send({
//         //         from: myWalletAddress,
//         //         gasLimit: web3.utils.toHex(15000000),
//         //         gasPrice: web3.utils.toHex(200000000000),
//         // })

//         // console.log("Repaid the borrow")
//         // d = await lpContract.methods.getUserAccountData(myWalletAddress).call()
//         // console.log(d);

//         let balance = await aETHContract.methods.balanceOf(myWalletAddress).call()
//         console.log(`Redeeming the balance of: ${balance}`)
//         // tr = await aETHContract.methods
//         //         .redeem(balance)
//         //         .send({
//         //                 from: myWalletAddress,
//         //                 gasLimit: web3.utils.toHex(15000000),
//         //                 gasPrice: web3.utils.toHex(200000000000),
//         //         })

//         // // console.log(tr)
//         // balance = await aETHContract.methods.balanceOf(myWalletAddress).call()
//         // console.log(`Balance left:                         ${balance}`)
//         // There seems to be some slippage occuring
//     });
// });




function delay(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}