pragma solidity ^0.5.0;


interface IProofValidator {
    function verifyTx(
        uint[2] calldata a,
        uint[2][2] calldata b,
        uint[2] calldata c,
        uint[3] calldata input)
    external returns (bool);
}