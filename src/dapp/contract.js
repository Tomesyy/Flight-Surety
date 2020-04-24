import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        this.config = Config[network];

        this.web3 = new Web3(new Web3.providers.HttpProvider(this.config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, this.config.appAddress);
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, this.config.dataAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }

    async setUp(callback) {
        await this.flightSuretyData.methods.setAuthorizedStatus(this.config.appAddress, true).send({from: this.owner});
        await this.flightSuretyData.methods.getAuthorizedStatus(this.config.appAddress).call({from: this.owner}, callback)
    }

    async isOperational(callback) {
       let self = this;
       await self.flightSuretyApp.methods.isOperational()
            .call({ from: self.owner}, callback);
    }

    async fetchFlightStatus(flight, callback) {
        let self = this;

        const flightDetails = await self.flightSuretyApp.methods.getFlight(flight).call();
        let payload = {
            airline: flightDetails.airline,
            flight: flightDetails.flight,
            timestamp: flightDetails.timestamp,
            statusCode: flightDetails.statusCode
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }

    async purchaseInsurance(flight, amount, callback){
        let self = this;
        const flightDetails = await self.flightSuretyApp.methods.getFlight(flight).call();
        let payload = {
            airline: flightDetails.airline,
            flight: flightDetails.flight,
            timestamp: flightDetails.timestamp,
            statusCode: flightDetails.statusCode
        }
        await self.flightSuretyApp.methods.purchaseInsurance(payload.airline, payload.flight, payload.timestamp)
            .send({from: self.owner, value: this.web3.utils.toWei(amount.toString(), 'ether'), gas: this.config.gas},
            async (error, result) => {
                const insurance = await this.flightSuretyApp.methods
                    .getInsurance(payload.flight)
                    .call({ from: this.owner });
                insurance.price = this.web3.utils.fromWei(insurance.price.toString(), 'ether')
                insurance.payoutPrice = this.web3.utils.fromWei(insurance.payoutPrice.toString(), 'ether')
                insurance.statusCode = payload.statusCode;
                insurance.airline = payload.airline;
                insurance.flight = payload.flight;
                insurance.timestamp = payload.timestamp;
                callback(error, insurance)
            })
    }

    async getFlights(callback) {
        let self = this;
        await self.flightSuretyApp.methods
            .getFlightsCount()
            .call({ from: self.owner }, async (err, flightsCount) => {
                const results = [];
                for (var i = 0; i < flightsCount; i++) {
                    const res = await self.flightSuretyApp.methods.getFlight(i).call({ from: self.owner });
                    results.push(res);
                }
                callback(err, results);
        });
    }

    async listenForFlightStatusUpdate(callback) {
        let self = this;
        await self.flightSuretyApp.events.FlightStatusInfo({fromBlock: 0}, (error, event) => {
            callback(error, event);

        });
    }

}