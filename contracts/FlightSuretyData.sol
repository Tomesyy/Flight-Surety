pragma solidity >=0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping(address => bool) authorizedCallers;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() public
    {
        contractOwner = msg.sender;
        airlines[contractOwner] = Airline({callerAddress:contractOwner, name:"First Airline", state:AirlineState.Paid, approvalCount:0});
        totalPaidAirlines++;
    }

    function()
    external
    payable
    {
    }

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
    modifier requireIsOperational() {
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

    modifier requireAuthorizedCaller() {
        require(authorizedCallers[msg.sender] || (msg.sender == contractOwner), "Caller is not authorized");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational() public view returns(bool) {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus( bool mode ) external requireContractOwner {
        operational = mode;
    }

    function setAuthorizedStatus(address caller, bool status) external requireContractOwner returns(bool) {
        authorizedCallers[caller] = status;
        return authorizedCallers[caller];
    }

    function getAuthorizedStatus(address caller) public view requireContractOwner returns(bool){
        return authorizedCallers[caller];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/


    /********************************************************************************************/
    /*                                     AIRLINE FUNCTIONS                             */
    /********************************************************************************************/

    struct Airline {
        address callerAddress;
        string name;
        AirlineState state;
        mapping(address => bool) approvals;
        uint8 approvalCount;
    }
    enum AirlineState {
        Applied,
        Registered,
        Paid
    }
    mapping(address => Airline) internal airlines;
    uint256 internal totalPaidAirlines = 0;


    function getAirlineState(address airlineAddress) external view requireAuthorizedCaller returns(uint state){
        if(airlines[airlineAddress].state == AirlineState.Applied){
            state = 0;
        }
        if(airlines[airlineAddress].state == AirlineState.Registered){
            state = 1;
        }
        if(airlines[airlineAddress].state == AirlineState.Paid){
            state = 2;
        }
    }

    function updateAirlineState(address airlineAddress, uint8 state) external requireAuthorizedCaller {
        airlines[airlineAddress].state = AirlineState(state);
        if(state == 2){
            totalPaidAirlines++;
        }
    }

    function getTotalPaidAirlines() external view requireAuthorizedCaller returns(uint256){
        return totalPaidAirlines;
    }

    function registerAirline(address airlineAddress, string name, uint8 state) external requireAuthorizedCaller {
        airlines[airlineAddress] = Airline({callerAddress:airlineAddress, name:name, state:AirlineState(state), approvalCount:0});
        if(state == 2){
            totalPaidAirlines++;
        }
    }

    function approveAirline(address airlineAddress, address approver) external requireAuthorizedCaller returns(uint8){
        require(airlines[airlineAddress].approvals[approver] == false, "duplicate approver");

        airlines[airlineAddress].approvals[approver] = true;
        airlines[airlineAddress].approvalCount++;

        return airlines[airlineAddress].approvalCount;
    }


    /********************************************************************************************/
    /*                                     PASSENGER INSURANCE FUNCTIONS                             */
    /********************************************************************************************/

    enum InsuranceState {
        Bought,
        Claimed
    }

    struct Insurance {
        string flight;
        uint256 price;
        uint256 payoutPrice;
        InsuranceState state;
    }

    mapping(address => mapping(string => Insurance)) private passengerInsurance;
    mapping(address => uint256) passengerBalance;


   /**
    * @dev Buy insurance for a flight
    *
    */
    function getInsurance(address passenger, string flight) external view requireAuthorizedCaller returns(
                                                             uint256 price,
                                                        uint256 payoutPrice,
                                                        InsuranceState state)
    {
        price = passengerInsurance[passenger][flight].price;
        payoutPrice = passengerInsurance[passenger][flight].payoutPrice;
        state = passengerInsurance[passenger][flight].state;
    }

    function createInsurance(address passenger, string flight, uint256 price, uint256 payoutPrice) external requireAuthorizedCaller {
        require(passengerInsurance[passenger][flight].price != price, "Insurance already exists");

        passengerInsurance[passenger][flight] = Insurance(flight, price, payoutPrice, InsuranceState.Bought);
    }

    function claimInsurance(address passenger, string flight) external requireAuthorizedCaller {
        require(passengerInsurance[passenger][flight].state == InsuranceState.Bought, "Insurance already claimed");

        passengerInsurance[passenger][flight].state = InsuranceState.Claimed;

        passengerBalance[passenger] = passengerBalance[passenger].add(passengerInsurance[passenger][flight].payoutPrice);
    }

    function getPassengerBalance(address passenger) external view requireAuthorizedCaller returns(uint256) {
        return passengerBalance[passenger];
    }

    function payPassenger(address passenger) external requireAuthorizedCaller {
        require(passengerBalance[passenger] > 0, "Passenger doesn't have enough to withdraw");

        passengerBalance[passenger] = 0;
        passenger.transfer(passengerBalance[passenger]);
    }


}

