import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        //setup contract
        contract.setUp((error, result) => {
            display('Error', 'Error seting up contract', [ { label: 'Setup Status', error: error, value: result} ]);
        })

        // Read transaction
        contract.isOperational((error, result) => {
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });

        contract.getFlights((error, results) => {
            const purchaseInsuranceSelect = DOM.elid('purchase-insurance-flights');
            let counter = 0;
            results.forEach((flight) => {
                const option = document.createElement('option');
                option.value = `${counter}-${flight.airline}-${flight.flight}-${flight.timestamp}`;
                const prettyDate = new Date(flight.timestamp * 1000).toDateString();
                option.textContent = `${flight.flight} on ${prettyDate}`;
                purchaseInsuranceSelect.appendChild(option);
                counter++;
            });
        })

        // contract.listenForFlightStatusUpdate((error, status) => {
        //     display('Oracle Response', 'Response from oracle', [ { label: 'Flight Status Returned', error: error, value: status.flight + ' ' + status.timestamp + ' ' + status.status} ]);
        // })
    

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp + ' ' + result.statusCode} ]);
            });
        })

        DOM.elid('buy-insurance').addEventListener('click', () => {
            let flight = DOM.elid('purchase-insurance-flights').value.split('-')[0];
            let fee = DOM.elid('purchase-insurance-amount').value;
            contract.purchaseInsurance(Number(flight), fee, (error, result) => {
                display('Flight Insurance', 'Purchase flight Insurance', [ { label: 'Purchase insurance for a flight', error: error, value: result.flight + ' ' + result.timestamp + ' ' + result.statusCode + ' price: ' + result.price + 'ETH -  payout-price: ' + result.payoutPrice + ' ETH'} ]);
            })
        })
    
    });
    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}







