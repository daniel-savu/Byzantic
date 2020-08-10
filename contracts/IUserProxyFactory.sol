pragma solidity ^0.5.0;

interface IUserProxyFactory {

    function registerAgent() external;

    function getUserProxyAddress(address userAddress) external view returns (address payable);

    function isUserProxy(address userProxyAddress) external view returns (bool);

}
