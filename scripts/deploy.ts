import { ethers } from "@nomiclabs/buidler";

async function deployContract(name: string) {
  console.log("----------------- deploying " + name + " -----------------")
  const factory = await ethers.getContract(name);
  let contract = await factory.deploy();
  console.log("Deploy Transaction hash: " + contract.deployTransaction.hash);
  await contract.deployed();
  console.log("Contract address: " + contract.address);
  console.log("");
}

async function main() {
  await deployContract("LBCR");
  await deployContract("WebOfTrust");
}
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });