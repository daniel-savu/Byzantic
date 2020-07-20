pragma solidity ^0.5.0;

interface ILBCR {
    function getCompatibilityScoreWith(address protocol) external view returns (uint256);

    function setCompatibilityScoreWith(address protocol, uint256 score) external;
}