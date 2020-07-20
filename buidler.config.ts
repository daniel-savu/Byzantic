import { BuidlerConfig, task, usePlugin } from "@nomiclabs/buidler/config";

usePlugin("@nomiclabs/buidler-waffle");
usePlugin("@nomiclabs/buidler-web3");
usePlugin("@nomiclabs/buidler-truffle5");
usePlugin("@nomiclabs/buidler-waffle");

// This is a sample Buidler task. To learn how to create your own go to
// https://buidler.dev/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, bre) => {
  const accounts = await bre.ethers.getSigners();

  for (const account of accounts) {
    console.log(await account);
  }
});


const LOCAL_NETWORK_PRIVATE_KEY = "0x710fd8db1b881e948e291d85ebde38829f774c79d99b775f88c99cbe3f4649c1";
const config: BuidlerConfig = {
  defaultNetwork: "buidlerevm",
  solc: {
    version: "0.5.14",
    optimizer: { enabled: true, runs: 200 },
    evmVersion: "istanbul"
  },
  networks: {
    localhost: {
      url: `http://127.0.0.1:2000`,
      accounts: [LOCAL_NETWORK_PRIVATE_KEY]
    },
    playground: {
      url: `http://127.0.0.1:2000`,
      accounts: [`0x01ad2f5ee476f3559b0d2eb8ec22968e847f0dcf3e1fc7ec02e57ecce5000548`],
      blockGasLimit: 16000000000,
      timeout: 200000
    },
  }
};



export default config;
