// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.8.0;

contract DhondtElectionRegion {
    uint[] results;
    uint numParties;
    uint regionId;
    mapping(uint => uint) private weights;
    constructor (uint nrParties, uint regId) {
        regionId = regId;
        numParties = nrParties;   
        savedRegionInfo();   
        results = new uint[](nrParties);  
    }
    
    function savedRegionInfo() private{
        weights[28] = 1; // Madrid
        weights[8] = 1; // Barcelona
        weights[41] = 1; // Sevilla
        weights[44] = 5; // Teruel
        weights[42] = 5; // Soria
        weights[49] = 4; // Zamora
        weights[9] = 4; // Burgos
        weights[29] = 2; // Malaga
    }

    function registerVote(uint party) internal returns (bool){
        if (party < numParties) {
            results[party] += weights[regionId];
            return true;
        }
        return false;
    }
}

abstract contract PollingStation {
    bool public votingFinished;
    bool private votingOpen;
    address public president;
    
    constructor (address pres) {
        votingFinished = false;
        votingOpen = false;
        president = pres;
    }

    modifier onlyPresident {
        require(msg.sender == president, "Only the president can call this function");
        _;
    }

    modifier votingAvailable {
        require(votingOpen && !votingFinished, "Voting is not available");
        _;
    }

    function openVoting () external onlyPresident {
        votingOpen = true;
    }

    function closeVoting () external onlyPresident{
        votingFinished = true;
    }

    function castVote (uint partyId) external virtual;
    function getResults () external virtual returns (uint[] memory);
}

contract DhondtPollingStation is DhondtElectionRegion, PollingStation {
    constructor(address president, uint number_of_parties, uint region_id)
    DhondtElectionRegion(number_of_parties, region_id)
    PollingStation(president){}

    function castVote(uint partyId) external override votingAvailable  {
        if(!registerVote(partyId)){
            revert("party id is not valid");
        }
    }

    function getResults() external override view returns (uint[] memory){
        if(!votingFinished){
            revert("Voting hasn't finished yet");
        }
        return results;
    }
}

contract Election{
    address owner;
    uint[] pollingStationsRegions;
    mapping (uint => DhondtPollingStation) pollingStations;
    uint number_of_parties;
    mapping(address => bool) voted;

    constructor(uint numb_of_parties){
        number_of_parties = numb_of_parties;
        owner = msg.sender;
    }

    modifier onlyAuthority {
        require(msg.sender == owner, "This function can only be called by the owner of the contract");
        _;
    }

    modifier freshId(uint region_id) {
        require(address(pollingStations[region_id]) == address(0), "This region already has an election");
        _;
    }

    modifier validId(uint region_id){
        require(address(pollingStations[region_id]) != address(0), "This region doesn't have an election yet");
        _;
    }

    function createPollingStation(uint region_id, address president) external freshId(region_id) onlyAuthority returns(address) {
        DhondtPollingStation pollingStation = new DhondtPollingStation(president, number_of_parties, region_id);
        pollingStationsRegions.push(region_id);
        pollingStations[region_id] = pollingStation;
        return address(pollingStation);
    }

    function castVote(uint region_id, uint party_id) external validId(region_id) {
        require(!voted[msg.sender], "This address has already voted");
        pollingStations[region_id].castVote(party_id);
    }

    function getResults() external view onlyAuthority returns (uint[] memory) {
        uint[] memory results = new uint[](number_of_parties);
        for(uint i = 0; i < pollingStationsRegions.length; i++ ){
            uint[] memory pollStationResults = pollingStations[pollingStationsRegions[i]].getResults();
            for(uint j = 0; j <number_of_parties; j++){
                results[j] += pollStationResults[j];
            }
        }
        return results;
    }
}