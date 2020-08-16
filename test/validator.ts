import env = require("@nomiclabs/buidler");
import { assert } from "console";

var web3 = env.web3;
var artifacts = env.artifacts;
var contract = env.contract;


const { expect } = require('chai');
const fs = require('fs');
const { randomHex } = require('web3-utils');

const Validator = artifacts.require('Verifier');

contract('Validator',  accounts => {
    let proofObject: any;
    let validator: typeof Validator;

    before(async function() {
        validator = await Validator.new();
        const rawProof = fs.readFileSync('./zkp/proof.json');
        proofObject = JSON.parse(rawProof);
    });

    xit('should validate proof', async function() {
        const { proof, inputs } = proofObject;
        let isValid = await validator.verifyTx(proof.a, proof.b, proof.c, inputs);
        assert(isValid == true);
    });

    xit('should reject fake inputs in proof', async () => {
        async function validateFakeInputs() {
            const { proof } = proofObject;
            const fakeInputs = [randomHex(32), randomHex(32), randomHex(32)];
            await validator.verifyTx(proof.a, proof.b, proof.c, fakeInputs);
        }

        expect(validateFakeInputs).to.throw
    });
});