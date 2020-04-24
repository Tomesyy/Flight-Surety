const truffleAssert = require('truffle-assertions');
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.setAuthorizedStatus(config.flightSuretyApp.address, true, {from: config.owner});
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it('flightSuretyApp is authorised to make calls to flightSuretyData', async function () {
    const status = await config.flightSuretyData.getAuthorizedStatus(config.flightSuretyApp.address, {from: accounts[0]});
    assert.equal(status, true, "flightSuretyApp is not authorized");
  });


  

  

  // AIRLINE TESTS


  it('creates contract owner as first airline ', async () => {
      assert.equal(await config.flightSuretyData.getAirlineState(accounts[0]), 2);
  })

  it('airlines can apply for registration', async () => {
    await config.flightSuretyApp.applyForAirline("Second airline", {from: accounts[1]});
    await config.flightSuretyApp.applyForAirline("third airline", {from: accounts[2]});
    await config.flightSuretyApp.applyForAirline("fourth airline", {from: accounts[3]});
    await config.flightSuretyApp.applyForAirline("fifth airline", {from: accounts[4]});

    var airline1State = await config.flightSuretyData.getAirlineState(accounts[1]);
    var airline2State = await config.flightSuretyData.getAirlineState(accounts[2]);
    var airline3State = await config.flightSuretyData.getAirlineState(accounts[3]);
    var airline4State = await config.flightSuretyData.getAirlineState(accounts[4]);


    assert.equal(airline1State, 0, "Airline not registered");
    assert.equal(airline2State, 0, "Airline not registered");
    assert.equal(airline3State, 0, "Airline not registered");
    assert.equal(airline4State, 0, "Airline not registered");
  })
 
  it('paid airline can approve another airline', async() => {
    await config.flightSuretyApp.approveAirline(accounts[1], { from: accounts[0]})
    await config.flightSuretyApp.approveAirline(accounts[2], { from: accounts[0]})
    await config.flightSuretyApp.approveAirline(accounts[3], { from: accounts[0]})
    

    var airline1State = await config.flightSuretyData.getAirlineState(accounts[1]);
    var airline2State = await config.flightSuretyData.getAirlineState(accounts[2]);
    var airline3State = await config.flightSuretyData.getAirlineState(accounts[3]);

    assert.equal(airline1State, 1, "Airline not registered");
    assert.equal(airline2State, 1, "Airline not registered");
    assert.equal(airline3State, 1, "Airline not registered");
  });

  it('can pay airline dues', async() => {
    await config.flightSuretyApp.payAirlineDue({from: accounts[1], value: web3.utils.toWei('10', 'ether')});
    await config.flightSuretyApp.payAirlineDue({from: accounts[2], value: web3.utils.toWei('10', 'ether')});
    await config.flightSuretyApp.payAirlineDue({from: accounts[3], value: web3.utils.toWei('10', 'ether')});

    var airline1State = await config.flightSuretyData.getAirlineState(accounts[1]);
    var airline2State = await config.flightSuretyData.getAirlineState(accounts[2]);
    var airline3State = await config.flightSuretyData.getAirlineState(accounts[3]);

    assert.equal(airline1State, 2, "Airline not registered");
    assert.equal(airline2State, 2, "Airline not registered");
    assert.equal(airline3State, 2, "Airline not registered");

    var contractBalance = await web3.eth.getBalance(config.flightSuretyData.address);

    assert.equal(web3.utils.fromWei(contractBalance, "ether"), 30, "Airline funds wasn't transfered to contract");

  });

  it('requires multiparty consensus for fifth airline approval', async() => {
      await config.flightSuretyApp.approveAirline(accounts[4], {from: accounts[0]});
      assert.equal(await config.flightSuretyData.getAirlineState(accounts[4]), 0, "Airline approved before consensus");
      await config.flightSuretyApp.approveAirline(accounts[4], {from: accounts[1]});
      await config.flightSuretyApp.approveAirline(accounts[4], {from: accounts[2]});
      assert.equal(await config.flightSuretyData.getAirlineState(accounts[4]), 1, "Airline approved before consensus");
  })


  // Passenger test

  it('Passenger can purchase flight insurance', async() => {
    const flight1 = await config.flightSuretyApp.getFlight(0);
    const amount = await config.flightSuretyApp.MAX_INSURANCE_AMOUNT.call();

    const expectedPayoutAmount = parseFloat(amount) + (parseFloat(amount)  / parseFloat(2) );
    await config.flightSuretyApp.purchaseInsurance(flight1.airline, flight1.flight, flight1.timestamp, {from: accounts[5], value: amount});

    const PassengerInsurance = await config.flightSuretyData.getInsurance(accounts[5], flight1.flight);

    assert.equal(parseFloat(PassengerInsurance.price), amount, "Wrong price");
    assert.equal(parseFloat(PassengerInsurance.payoutPrice), expectedPayoutAmount, "Wrong Payout");
  })

  it('Passenger cannot buy the same exact insurance', async() => {
      const flight1 = await config.flightSuretyApp.getFlight(0);
      const amount = await config.flightSuretyApp.MAX_INSURANCE_AMOUNT.call();
      
      var failed = false;

      try {
        await config.flightSuretyApp.purchaseInsurance(flight1.airline, flight1.flight, flight1.timestamp, {from: accounts[5], value: amount});
      } catch(err){
        failed =true;
      }

      assert.equal(failed, true, "Passenger was able to buy the same insurance twice");
  })

  it('Passenger cannot buy more than one ether insurance', async() => {
    const flight1 = await config.flightSuretyApp.getFlight(0);
    let amount = await config.flightSuretyApp.MAX_INSURANCE_AMOUNT.call();
    amount = amount + amount;
    
    var failed = false;

    try {
        await config.flightSuretyApp.purchaseInsurance(flight1.airline, flight1.flight, flight1.timestamp, {from: accounts[5], value: amount});
    } catch(err) {
        failed = true;
    }
    
    assert.equal(failed, true, "Passenger was able to purchase insurance worth more than 1 ether");
  })

  it('can fetch flight status', async () => {
    const flight1 = await config.flightSuretyApp.getFlight(0);

    const fetchFlightStatus = await config.flightSuretyApp.fetchFlightStatus(
        flight1.airline,
        flight1.flight,
        flight1.timestamp,
    );

    truffleAssert.eventEmitted(fetchFlightStatus, 'OracleRequest', (ev) => {
        return ev.airline === flight1.airline;
    });
  })



});
