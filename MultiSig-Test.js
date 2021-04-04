const { ethers } = require('hardhat');
const { expect } = require("chai");
const { BigNumber } = require("ethers");

let owner1, owner2, owner3, user1;
let MultiSig, multiSig;

describe('Instantiation', () => {
    before(async () => {
        [owner1, owner2, owner3, user1] = await ethers.getSigners();

        MultiSig = await ethers.getContractFactory("MultiSig");
        multiSig = await MultiSig.connect(owner1).deploy([owner1.address, owner2.address, owner3.address]);
        await multiSig.deployed();
    });

    it('Construtor works correctly', async () => {
        expect(await multiSig.getOwners()).to.equal([owner1, owner2, owner3]);
    });
});
