pragma solidity ^0.5.0;

interface IWebOfTrust {
    function getAggregateAgentFactorForProtocol(address agent, address protocol) external view returns (uint256);

    function getAgentFactorDecimals() external view returns (uint);

    function addProtocolIntegration(address protocolAddress, address protocolProxyAddress) external;

    function isProtocolProxy(address addr) external returns (bool);

    function getProtocolLBCR(address protocolAddress) external view returns (address);
}
