pragma solidity ^0.5.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
 */
interface ILBCR {
    function getCompatibilityScoreWith(address protocol) external view returns (uint256);

    function setCompatibilityScoreWith(address protocol, uint256 score) external;
}