var LBCR = artifacts.require("./LBCR.sol");
// var ByzanticCompound = artifacts.require("./ByzanticCompound.sol");
// var ByzanticAaveProxy = artifacts.require("./ByzanticAaveProxy.sol");
var UserProxy = artifacts.require("./UserProxy.sol");
var Byzantic = artifacts.require("./Byzantic.sol");
// var FlashLoanExecutor = artifacts.require("./FlashLoanExecutor.sol");
// var InitializableAdminUpgradeabilityProxy = artifacts.require("./InitializableAdminUpgradeabilityProxy.sol");
var lpAddressProviderAddress = '0x24a42fD28C976A61Df5D00D0599C34c4f90748c8';
var LendingPoolAddressesProviderABI = require("../test/ABIs/LendingPoolAddressesProvider.json");



module.exports = function (deployer) {
    deployer.deploy(LBCR);
    // deployer.deploy(ByzanticCompound);
    // deployer.deploy(ByzanticAaveProxy);
    // deployer.deploy(UserProxy);
    deployer.deploy(Byzantic);
    // const lpAddressProviderContract = new web3.eth.Contract(LendingPoolAddressesProviderABI, lpAddressProviderAddress)
    // deployer.deploy(FlashLoanExecutor, lpAddressProviderContract.options.address);
    // deployer.deploy(InitializableAdminUpgradeabilityProxy);
};