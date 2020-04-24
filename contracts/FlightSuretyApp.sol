pragma solidity >=0.4.24;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/


    address private contractOwner;          // Account used to deploy contract
    bool private operational = true;
    
    FlightSuretyData flightSuretyData;
    address flightSuretyDataContractAddress;


    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational()
    {
         // Modify to call data contract's status
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier onlyPaidAirlines() {
        require(flightSuretyData.getAirlineState(msg.sender) == 2, "Only paid airlines allowed");
        _;
    }
    modifier onlyApprovedAirlines() {
        require(flightSuretyData.getAirlineState(msg.sender) == 1, "Only approved airlines allowed");
        _;
    }
    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address flightSuretyDataAddress) public {
        contractOwner = msg.sender;
        flightSuretyDataContractAddress = flightSuretyDataAddress;
        flightSuretyData = FlightSuretyData(flightSuretyDataContractAddress);

        bytes32 flightKey1 = getFlightKey(contractOwner, "FLIGHT1", now);
        flights[flightKey1] = Flight("FLIGHT1", STATUS_CODE_UNKNOWN, now, contractOwner);
        flightsKeyList.push(flightKey1);

        bytes32 flightKey2 = getFlightKey(contractOwner, "FLIGHT2", now + 1 days);
        flights[flightKey2] = Flight( "FLIGHT2", STATUS_CODE_UNKNOWN, now + 1 days, contractOwner);
        flightsKeyList.push(flightKey2);

        bytes32 flightKey3 = getFlightKey(contractOwner, "FLIGHT3", now + 2 days);
        flights[flightKey3] = Flight("FLIGHT3",STATUS_CODE_UNKNOWN, now + 2 days, contractOwner);
        flightsKeyList.push(flightKey3);
    }

    function isOperational() public view returns (bool)
    {
        return operational;
    }

    function setOperatingStatus (bool mode) external requireContractOwner
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /********************************************************************************************/
    /*                                     AIRLINE FUNCTIONS                             */
    /********************************************************************************************/
   /**
    * @dev Add an airline to the registration queue
    *
    */
    event AirlineApplied(address airline);
    event AirlineApproved(address airline);
    event AirlinePaid(address airline);

    uint8 private constant NumberOfAirlinesRequiredForConsensusVoting = 4;

    function applyForAirline(string airlineName) external {
        flightSuretyData.registerAirline(msg.sender, airlineName, 0);
        emit AirlineApplied(msg.sender);
    }

    function approveAirline(address airline) external onlyPaidAirlines {
        require(flightSuretyData.getAirlineState(airline) == 0, "This airline has not applied for approval");

        uint256 totalPaidAirlines = flightSuretyData.getTotalPaidAirlines();

        if(NumberOfAirlinesRequiredForConsensusVoting > totalPaidAirlines ){
            flightSuretyData.updateAirlineState(airline, 1);
            emit AirlineApproved(airline);
        } else {
            uint8 approvalCount = flightSuretyData.approveAirline(airline, msg.sender);
            uint256 totalApprovalRequired = totalPaidAirlines.div(2);
            if(approvalCount > totalApprovalRequired) {
                flightSuretyData.updateAirlineState(airline, 1);
                emit AirlineApproved(airline);
            }
        }
    }

    function payAirlineDue() external payable onlyApprovedAirlines {
        require(msg.value == 10 ether, "you're required to pay 10 ethers");

        flightSuretyDataContractAddress.transfer(msg.value);
        flightSuretyData.updateAirlineState(msg.sender, 2);
        emit AirlinePaid(msg.sender);
    }
    
    /********************************************************************************************/
    /*                         PASSENGER FUNCTIONS                                                */
    /********************************************************************************************/

    uint public constant MAX_INSURANCE_AMOUNT = 1 ether;

    event PassengerInsuranceBought(address passenger, bytes32 flightKey);

    function purchaseInsurance(address airline, string flight, uint256 timestamp) external payable {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        require(bytes(flights[flightKey].flight).length > 0, "Flight does not exist");

        require(msg.value <= MAX_INSURANCE_AMOUNT, "Passengers can buy a maximum of 1 ether for insurance");
    
        flightSuretyDataContractAddress.transfer(msg.value);

        uint256 payoutAmount = msg.value + ( msg.value / 2);

        flightSuretyData.createInsurance(msg.sender, flight, msg.value, payoutAmount);

        emit PassengerInsuranceBought(msg.sender, flightKey);
    }

    function getInsurance(string flight) external view returns(uint256 price, uint256 payoutPrice, uint256 state) {
        return flightSuretyData.getInsurance(msg.sender, flight);
    }

    function claimInsurance(address airline, string flight, uint256 timestamp) external {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        require(flights[flightKey].statusCode == STATUS_CODE_LATE_AIRLINE, "flight was not delayed");

        flightSuretyData.claimInsurance(msg.sender, flight);
    }

    function getBalance() external view returns(uint256 balance) {
        balance = flightSuretyData.getPassengerBalance(msg.sender);
    }

    function withdrawBalance() external {
        flightSuretyData.payPassenger(msg.sender);
    }


    /********************************************************************************************/
    /*                         FLIGHTS FUNCTIONS                                                */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    

    struct Flight {
        string flight;
        uint8 statusCode;
        uint256 timestamp;
        address airline;
    }
    mapping(bytes32 => Flight) private flights;
    bytes32[] private flightsKeyList;

    event FlightStatusProcessed(address airline, string flight, uint8 statusCode);

    function getFlightsCount() external view returns(uint256 count) {
        return flightsKeyList.length;
    }
    
    function getFlight(uint256 index) external view returns (address airline, string flight, uint256 timestamp, uint8 statusCode){
        airline = flights[flightsKeyList[index]].airline;
        flight = flights[flightsKeyList[index]].flight;
        timestamp = flights[flightsKeyList[index]].timestamp;
        statusCode = flights[flightsKeyList[index]].statusCode;
    }

    function registerFlight(uint8 status, string flight) external
    onlyPaidAirlines {
        bytes32 flightKey = getFlightKey(msg.sender, flight, now);

        flights[flightKey] = Flight(flight, status, now, msg.sender);
        flightsKeyList.push(flightKey);
    }
   /**
    * @dev Called after oracle has updated flight status
    *
    */
    function processFlightStatus( address airline, string memory flight,
                                  uint256 timestamp, uint8 statusCode ) internal {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        flights[flightKey].statusCode = statusCode;

        emit FlightStatusProcessed(airline, flight, statusCode);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    }

// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            external
                            view
                            returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) ||
         (oracles[msg.sender].indexes[1] == index) ||
         (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        internal
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes ( address account)
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion
}
/********************************************************************************************/
/*                             STUB FOR DATA CONTRACT                                        */
/********************************************************************************************/

contract FlightSuretyData {
    function getAirlineState(address airlineAddress) view returns (uint){
        return 1;
    }

    function updateAirlineState(address airlineAddress, uint8 state) view {

    }

    function getTotalPaidAirlines() view returns(uint) {
        return 1;
    }

    function registerAirline(address airlineAddress, string name, uint8 state) view {

    }

    function approveAirline(address airlineAddress, address approver) view returns(uint8){
        return 1;
    }

    function getInsurance(address passengerAddress, string flight) view
                                                                returns (
                                                                    uint256 price,
                                                                    uint256 payoutPrice,
                                                                    uint8 state
                                                                ){
        price = 1;
        payoutPrice = 1;
        state = 1;
    }

    function createInsurance(address passengerAddress, string flight, uint256 price, uint256 payoutPrice) view 
    {}

    function claimInsurance(address passengerAddress, string flight) view 
    {}

    function getPassengerBalance(address passenger) returns(uint256){
        return 1;
    }

    function payPassenger(address passenger) view 
    {}



}
