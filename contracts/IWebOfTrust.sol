pragma solidity ^0.5.0;

interface IWebOfTrust {
    function getAggregateAgentFactorForProtocol(address agent, address protocol) external view returns (uint256);

    function getUserFactorDecimals() external view returns (uint);

    function addProtocolIntegration(address protocolAddress, address protocolProxyAddress) external;

    function isProtocolProxy(address addr) external returns (bool);
}
