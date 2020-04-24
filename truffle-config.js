var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "twin nasty bargain fork poem exhibit online when crazy present vendor version";

module.exports = {
  networks: {
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/", 0, 50);
      },
      network_id: '*',
      gas: 6721975
    }
  },
  rinkeby: {
    // provider: () => new HDWalletProvider(mnemonic, `https://rinkeby.infura.io/v3/aec03ee293634f0e87c32e540164ce49`),
    // network_id: 4,       // Ropsten's id
    // gas: 5500000,        // Ropsten has a lower block limit than mainnet
    //confirmations: 2,    // # of confs to wait between deployments. (default: 0)
    //timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
    //skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
  },
  compilers: {
    solc: {
      version: "^0.4.24"
    }
  }
};