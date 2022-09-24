require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-etherscan');
require('hardhat-deploy');
require('solidity-coverage');
require('hardhat-gas-reporter');
require('hardhat-contract-sizer');
//require('dotenv').config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */

const GOERLI_RPC_URL = process.env.GOERLI_RPC_URL;

module.exports = {
  defaultNetwork: 'hardhat',
  networks: {
    ganache: {
      url: 'http://127.0.0.1:7545',
    },
  },
  solidity: '0.8.7',
};
