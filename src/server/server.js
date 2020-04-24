import 'babel-polyfill';
import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import BigNumber from 'bignumber.js';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));



let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
init();


async function init() {
  try {
    const numberOfOracles = 20;
    const accounts = await web3.eth.getAccounts();
    const oracles = [];
    const fee = await flightSuretyApp.methods.REGISTRATION_FEE().call({from: accounts[0]});
    const STATUS_CODES = [0, 10, 20, 30, 40, 50];

    for(let i = 0; i < numberOfOracles; i++){
      await flightSuretyApp.methods.registerOracle().send({from: accounts[i], value: fee, gas: 3000000});
      const indexes = await flightSuretyApp.methods.getMyIndexes().call({from: accounts[i]});
      oracles.push({
        address: accounts[i],
        indexes: indexes
      })
    }

    console.log(oracles);

    await flightSuretyApp.events.OracleRequest({
        fromBlock: 0
      }, function (error, event) {
        if (error) {
          console.log(error)
        }

        console.log("New request ************************")

        const index = event.returnValues.index;
        const airline = event.returnValues.airline;
        const flight = event.returnValues.flight;
        const timestamp = event.returnValues.timestamp;

        
        console.log(index, airline, flight, timestamp);

        const relevantOracles = [];
        oracles.forEach(oracle => {
          for(let i = 0; i < oracle.indexes.length; i++){
            if(BigNumber(oracle.indexes[i]).isEqualTo(index)){
              relevantOracles.push(oracle);
            }
          }
        })

        relevantOracles.forEach( async (oracle) => {
          const status = STATUS_CODES[Math.floor(Math.random() * (STATUS_CODES.length))]
          await flightSuretyApp.methods
              .submitOracleResponse(index, airline, flight, timestamp, status)
              .send({ from: oracle.address, gas: 5555555 })
              .then(() => {
                  console.log("Oracle responded with " + status);
              })
              .catch((err) => console.log("Oracle response rejected"));
      });
    });
  } catch(err) {
    console.log(err);
  }
}


const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


