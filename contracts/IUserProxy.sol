pragma solidity ^0.5.0;

interface IUserProxy {

    function withdrawFunds(address _reserve, uint256 _amount) external;

    function depositFunds(address _reserve, uint256 _amount) external payable;

    function getReserveBalance(address _reserve) external view returns(uint256);

}
