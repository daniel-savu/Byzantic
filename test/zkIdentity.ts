// import env = require("@nomiclabs/buidler");
// import { assert } from "console";

// var web3 = env.web3;
// var artifacts = env.artifacts;
// var contract = env.contract;


// const { expect } = require('chai');
// const fs = require('fs');
// const { randomHex } = require('web3-utils');

// const ZkIdentity = artifacts.require('./ZkIdentity');
// const Validator = artifacts.require('Verifier');


// contract('ZkIdentity',  accounts => {
//     let proofObject: any;
//     let zkIdentity: typeof ZkIdentity;
//     let validator: typeof Validator;
//     let firstHash: any;
//     let secondHash: any;

//     before(async function() {
//         validator = await Validator.new();
//         zkIdentity = await ZkIdentity.new(validator.address);
//         const rawProof = fs.readFileSync('./zkp/proof.json');
//         proofObject = JSON.parse(rawProof);
//         (
//             { inputs: [firstHash, secondHash] } = proofObject
//         );
//     });

//     describe('ZkIdentity functionality', async () => {
//         it('should perform a privacy-preserving call', async () => {
//             await zkIdentity.setReputationAddressAuthentication(firstHash, secondHash);

//             const proof = encodeProof(proofObject);

//             const { receipt } = await zkWallet.zkRecover(recoveryAddress, proof);
//         });
//     });

//     it('should reject fake inputs in proof', async () => {
//         async function validateFakeInputs() {
//             const { proof } = proofObject;
//             const fakeInputs = [randomHex(32), randomHex(32), randomHex(32)];
//             await validator.verifyTx(proof.a, proof.b, proof.c, fakeInputs);
//         }

//         expect(validateFakeInputs).to.throw
//     });
// });