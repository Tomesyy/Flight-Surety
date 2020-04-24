const truffleAssert = require('truffle-assertions');
var Test = require('../config/testConfig.js');
//var BigNumber = require('bignumber.js');

contract('Oracles', async (accounts) => {

  const TEST_ORACLES_COUNT = 20;
  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);

    // Watch contract events
    const STATUS_CODE_UNKNOWN = 0;
    const STATUS_CODE_ON_TIME = 10;
    const STATUS_CODE_LATE_AIRLINE = 20;
    const STATUS_CODE_LATE_WEATHER = 30;
    const STATUS_CODE_LATE_TECHNICAL = 40;
    const STATUS_CODE_LATE_OTHER = 50;

  });

  const oracles = [];

  it('can register oracles', async () => {
    
    let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

    // ACT
    for(let a=1; a<TEST_ORACLES_COUNT; a++) {      
      if (!accounts[a]) break;

      await config.flightSuretyApp.registerOracle({ from: accounts[a], value: fee });
      let indexes = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a]});
      console.log(`Oracle Registered: ${indexes[0]}, ${indexes[1]}, ${indexes[2]}`);

      oracles.push({
        address: accounts[a],
        indexes: indexes
      })

    }

    it('can fetch flight status', async() => {
      const airline = accounts[0];
      const flight = 'ND1309';
      const timestamp = Math.floor(Data.now() / 1000);

      const oracleRequest = await config.flightSuretyApp.fetchFlightStatus(airline, flight, timestamp);

      let index;

      truffleAssert.eventEmitted(oracleRequest, 'OracleRequest', (ev) => {
        index = ev.index;
        return ev.flight === flight;
      })
      
      const relevantOracle = [];

      oracles.forEach(oracle => {
        for(let i = 0; i < 3; i++){
          if(oracle.indexes[i] === index){
            relevantOracle.push(oracle);
          }
        }
      })

      if(relevantOracle.length < 3){
        console.warn("Not enough Oracles to pass, try running test again");
      }

      await config.flightSuretyApp.submitOracleResponse(index, airline, flight, timestamp, STATUS_CODE_ON_TIME, {from: relevantOracle[0]});

      truffleAssert.eventEmitted(submitOracleResponse, 'OracleReport', (ev) => {
        return ev.airline === airline && ev.flight === flight;
    });
    })
  });



  


 
});
