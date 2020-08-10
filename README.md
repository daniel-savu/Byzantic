# Byzantic

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]







<!-- TABLE OF CONTENTS -->
## Table of Contents

* [About the Project](#about-the-project)
  * [Built With](#built-with)
* [Getting Started](#getting-started)
  * [Integrating](#integrating)
  * [Usage](#usage)
* [Contributing](#contributing)
  * [Prerequisites](#prerequisites)
  * [Usage Examples](#usage-examples)
  * [Documentation](#documentation)
* [Roadmap](#roadmap)
* [License](#license)



<!-- ABOUT THE PROJECT -->
## About The Project

<img src="images/architecture.png" alt="Architecture Diagram">

Byzantic aims to compute cross-protocol reputation for DeFi users. By performing desired actions in one protocol, the user can reduce
their collateral ratio across all protocols that integrate with Byzantic.

Protocols that integrate with Byzantic need to change the portion of their code that retrieves collateralization ratios. Besides using action specific collateralization ratios, protocols should query Byzantic to learn if the user deserves a reduction in collateral. For instance, if borrowing an asset requires 150% overcollateralization and the borrowing user has a good reputation across DeFi, Byzantic may deem the user worthy of only paying 90% of the collateral (90% x 150% = 135% overcollateralization). 

For every protocol that integrates with this solution, Byzantic will keep a Layered Behaviour-Curated Registry (LBCR) of users, which assigns agents (users) into layers, higher layers corresponding to lower collateral. Byzantic is a round-based protocol. For every LBCR, at the end of a round users are either promoted to a higher layer, demoted, or kept in the same layer, based on the actions they have taken during the round and how much they were in accordance with the interests of protocols. When Byzantic is queried about the reputation of a user, it aggregates information from every LBCR and produces a general score (this is done in the Web of Trust contract). Not all DeFi protocols are identical and good reputation in one protocol may not directly translate into good reputation in another protocol (the intuition is that if a person is a good scientist, we may not assume that consequently they are a good sports player, but it is more reasonable to assume that they are a good teacher). Protocol governance or admins will decide, for every other protocol that integrates with Byzantic, on a value between 0 and 1 that encodes how much of the reputation in the other protocols applies to their protocol.

### Built With
* [Solidity 0.5](https://solidity.readthedocs.io/en/v0.5.0/050-breaking-changes.html)
* [TypeScript](https://www.typescriptlang.org/)
* [Buidler](https://buidler.dev/)
* [Truffle](https://www.trufflesuite.com/truffle)



<!-- GETTING STARTED -->
## Getting Started

### Integrating

* Deploy a protocol proxy contract. This contract is used to properly track and update agents' reputation score based on their transactions. See `contracts/SimpleLendingProxy.sol`, which is a proxy for the example protocol `contracts/SimpleLending/SimpleLending.sol`.
* Once the protocol proxy is deployed, call the WebOfTrust contract using the method: `addProtocolIntegration(address protocolAddress, address protocolProxyAddress)`. An example can be found in the global `before()` function in `test/byzantic.ts`, where the dummy SimpleLending protocol is deployed, along with SimpleLendingTwo, a clone protocol.
* WebOfTrust will automatically deploy a Layered Behaviour-Curated Registry (LBCR) contract for your protocol integration. Retrieve it using the function `getProtocolLBCR(address protocolAddress)` and then initialize the LBCR  using parameters you deem appropriate. 
* LBCR parameters define the number of layers, the collateral discount offered by each layer, the score needed to be in a certain layer, and the compatibility scores with all the other protocols in Byzantic. The compatibility scores are the weightings used to lower their collateral in your protocol by using reputation in other protocols. The weighting of your own protocol is 100. For example, you can allow users to use their reputation from two other protocols, by setting the compatibility scores of those protocols to 2 and 3 respectively. The aggregated reputation will use the LBCR layer factor in your protocol with a weighting of `100 / (100 + 2 + 3)`, the LBCR layer factor in the second protocol with a weighting of `2 / (100 + 2 + 3)` and the LBCR layer factor in the third protocol with a weighting of `3 / (100 + 2 + 3)`. 
* See the function `initializeLBCR(LBCRAddress: string, layers: number[], layerFactors: number[], layerLowerBounds: number[], layerUpperBounds: number[])` and `initializeSimpleLendingLBCR(webOfTrust: typeof WebOfTrust)` in `test/byzantic.ts` for an example LBCR initialization.

### Usage

For protocols that integrate with Byzantic, usage is defined by the `IWebOfTrust` interface. Most likely, the most common functions your protocol will call are `getAggregateAgentFactorForProtocol(address agent, address protocol)` and `getAgentFactorDecimals()`. You can find example usages of these functions in `getCollateralInUseInETH(address account)` and `getBorrowableAmountInETH(address account)` in `contracts/SimpleLending/SimpleLending.sol`.

For users of a protocol who want to register with Byzantic, usage is defined by the `IUserProxyFactory` and `IUserProxy`interfaces. First, use the `registerAgent` function to register in the `UserProxyFactory`, which will deploy a `UserProxy` contract for you and will register you in every LBCR. Then, call `getUserProxyAddress(address userAddress)` in `UserProxyFactory` to get the address of your `UserProxy`. To deposit and withdraw funds and your user proxy, use the `depositFunds(address _reserve, uint256 _amount)` and `withdrawFunds(address _reserve, uint256 _amount)` functions.

For further code examples, check the tests in `test/byzantic.ts`, which can be run by following the instructions in the [Contributing](#Contributing) section.

<!-- Contributing -->
## Contributing

First, clone this repository to your machine and then install the prerequisites.

### Prerequisites

To install dependencies, run:
```sh
npm install --save-dev
```

### Running tests

The test showcases how Byzantic can be used to aggregate reputation from two identical "simple lending protocols" (SimpleLending and SimpleLendingTwo). For testing purposes, a basic ERC-20 token was used to mock Dai. Exchange price between ETH and DaiMock is based on the liquidity available in the lending protocols.

There is no need to connect to an Ethereum node, as Buidler runs the tests in its custom Buidler EVM, which facilitates debugging.

Run:
```sh
npx buidler test
```


### Documentation

You can find the static HTML documentation page [here](https://htmlpreview.github.io/?https://github.com/savudani8/Byzantic/blob/master/docs/website/build/site/contracts/1/index.html), generated automatically using [solidity-docgen](https://github.com/OpenZeppelin/solidity-docgen) and [Antora](https://antora.org/).

<!-- ROADMAP -->
## Roadmap

* Preserve user privacy by using [AZTEC](https://www.aztecprotocol.com/) to obfuscate transactions.
* Perform stress testing of the protocol using statistical methods, to prove its reliability in the face of price shocks (similar to the approach in [this research paper](https://arxiv.org/pdf/2002.08099.pdf)).
* See the [open issues](https://github.com/savudani8/Byzantic/issues) for a list of proposed features (and known issues).


<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE` for more information.



<!-- MARKDOWN LINKS & IMAGES -->
[contributors-shield]: https://img.shields.io/github/contributors/savudani8/Byzantic.svg?style=flat-square
[contributors-url]: https://github.com/savudani8/Byzantic/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/savudani8/Byzantic.svg?style=flat-square
[forks-url]: https://github.com/savudani8/Byzantic/network/members
[stars-shield]: https://img.shields.io/github/stars/savudani8/Byzantic.svg?style=flat-square
[stars-url]: https://github.com/savudani8/Byzantic/stargazers
[issues-shield]: https://img.shields.io/github/issues/savudani8/Byzantic.svg?style=flat-square
[issues-url]: https://github.com/savudani8/Byzantic/issues
[license-shield]: https://img.shields.io/github/license/savudani8/Byzantic.svg?style=flat-square
[license-url]: https://github.com/savudani8/Byzantic/blob/master/LICENSE.txt
[product-screenshot]: images/architecture.png
