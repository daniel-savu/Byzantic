pragma solidity ^0.5.0;

interface IByzantic {
    function getBaseCollateralisationRate() external view returns (uint256);

    function setBaseCollateralisationRate(uint baseCollateralisationRateValue) external;
}
