pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@nomiclabs/buidler/console.sol";
import "./ILBCR.sol";

contract LBCR is Ownable, ILBCR {
    address[] authorisedContracts;

    uint256 _decimals; // decimals to calculate collateral factor

    // Implementation of L = (lower, upper, factor)
    mapping (uint256 => uint[]) _layers; // array of layers, e.g. {1,2,3,4}
    mapping (uint256 => mapping (uint256 => uint256)) _lower; // versioned lower bound of layer
    mapping (uint256 => mapping (uint256 => uint256)) _upper; // versioned upper bound of layer
    mapping (uint256 => mapping (uint256 => uint256)) _factors; // versioned factor of layer
    mapping (uint256 => mapping (uint256 => uint256)) _rewards; // versioned reward (score) for performing an action

    mapping(address => uint256) compatibilityScores;
    mapping(address => uint256) compatibilityScoreVersions;
    bool maintainCompatibilityScoreOnUpdate = true;
    uint256 _latestVersion;
    uint256 _currentVersion;


    // Implementation of the registry
    mapping (uint256 => mapping (address => uint256)) _assignments; // layer assignment by round and agent
    mapping (uint256 => mapping (address => uint256)) _scores; // score by round and agent
    mapping (address => uint256) _interactionCount;
    uint256 _round; // current round in the protocol
    
    mapping (address => bool) _agents; // track all agents
    address[] agentList;

    uint256 _blockperiod; // block period until curation
    uint256 _start; // start of period
    uint256 _end; // end of period
    mapping(address => uint256) timeDiscountedFactors;

    uint256 recentFactorTimeDiscount;
    uint256 olderFactorTimeDiscount;



    constructor() public {
        addAuthorisedContract(msg.sender);
        // console.log(msg.sender);
        // console.log(owner());
        _decimals = 3; // e.g. a factor of 1500 is equal to 1.5 times the collateral
        _round = 0; // init rounds
        
        _blockperiod = 1; // wait for 1 block to curate
        _start = block.number;
        _end = block.number + _blockperiod;

        recentFactorTimeDiscount = 400;
        olderFactorTimeDiscount = 600;

        _latestVersion = 1;
        _currentVersion = 0;
    }

    function addAuthorisedContract(address authorisedContract) public onlyAuthorised {
        authorisedContracts.push(authorisedContract);
    }

    modifier onlyAuthorised() {
        bool isAuthorised = false;
        if(isOwner()) {
            isAuthorised = true;
        }
        for (uint i = 0; i < authorisedContracts.length; i++) {
            if(authorisedContracts[i] == msg.sender) {
                isAuthorised = true;
                break;
            }
        }
        require(isAuthorised == true, "Caller is not authorised to perform this action");
        _;
    }

    function getCompatibilityScoreWith(address protocol) external view returns (uint256) {
        if(protocol == address(this)) {
            return 100;
        }
        if(_currentVersion == compatibilityScoreVersions[protocol] || maintainCompatibilityScoreOnUpdate) {
            return compatibilityScores[protocol];
        }
        
        return 0;
    }

    function setCompatibilityScoreWith(address protocol, uint256 score) external onlyAuthorised {
        compatibilityScores[protocol] = score;
        compatibilityScoreVersions[protocol] = _latestVersion;
    }

    function setMaintainCompatibilityScoreOnUpdate(bool maintainCompatibilityScoreOnUpdateValue) external onlyAuthorised {
        maintainCompatibilityScoreOnUpdate = maintainCompatibilityScoreOnUpdateValue;
    }

    function getMaintainCompatibilityScoreOnUpdate() external view returns (bool) {
        return maintainCompatibilityScoreOnUpdate;
    }
    
    function incrementLatestVersion() external onlyAuthorised {
        _latestVersion += 1;
    }

    function upgradeVersion() external onlyAuthorised {
        _currentVersion = _latestVersion;
    }
    
    // ##############
    // ### LAYERS ###
    // ##############

    function getLayers() public view returns(uint[] memory) {
        return _layers[_currentVersion];
    }

    function setLayers(uint8[] memory layers) public onlyAuthorised {
         // set layers
        _layers[_latestVersion] = layers;
    }

    function resetLayers() external onlyAuthorised {
        delete _layers[_currentVersion];
    }

    function addLayer(uint layer) external onlyAuthorised {
        _layers[_latestVersion].push(layer);
    }

    // ##############
    // ### FACTOR ###
    // ##############
    function getAgentFactor(address agent) public view returns (uint256) {
        uint assignment = getAssignment(agent);

        require(assignment > 0, "agent not assigned to layer");

        return timeDiscountedFactors[agent];
    }

    function getFactor(uint layer) public view returns (uint256) {
        return _factors[_currentVersion][layer];
    }

    function setFactor(uint layer, uint256 factor) public onlyAuthorised returns (bool) {
        require(_latestVersion != _currentVersion, "LatestVersion must be incremented before updating");
        _factors[_latestVersion][layer] = factor;
        return true;
    }

    // ###############
    // ### REWARD ###
    // ###############

    function getReward(uint256 action) public view returns (uint256) {
        return _rewards[_currentVersion][action];
    }

    function setReward(uint256 action, uint256 reward) public onlyAuthorised returns (bool) {
        require(_latestVersion != _currentVersion, "LatestVersion must be incremented before updating");
        _rewards[_latestVersion][action] = reward;
        return true;
    }

    // ###############
    // ### BOUNDS ###
    // ###############

    function getBounds(uint layer) public view returns (uint256, uint256) {
        return (_lower[_currentVersion][layer], _upper[_currentVersion][layer]);
    }

    function setBounds(uint layer, uint256 lower, uint256 upper) public onlyAuthorised returns (bool) {
        _lower[_currentVersion][layer] = lower;
        _upper[_currentVersion][layer] = upper;

        emit NewBound(lower, upper);

        return true;
    }

    event NewBound(uint256 lower, uint256 upper);

    // ######################
    // ### AGENT REGISTRY ###
    // ######################

    function getAssignment(address agent) public view returns(uint assignment) {
        // check if agent is registered
        if (_agents[agent]) {
            // check if agent is assigned to a layer in the current round
            if (_assignments[_round][agent] == 0) {
                // check if the agent was assigned to a layer in previous rounds
                for (uint i = 1; i < _layers[_currentVersion].length && i < _round; i++) {
                    if (_assignments[_round - i][agent] > i) {
                        return _assignments[_round - i][agent] - i;
                    }
                }
                return 1;
            } else {
                return _assignments[_round][agent];
            }
        } else {
            return 0;
        }
    }

    function getScore(address agent) public view returns (uint256) {
        uint assignment = getAssignment(agent);

        require(assignment > 0, "agent not assigned to layer");

        return _scores[_round][agent];
    }

    function getInteractionCount(address agent) public view returns (uint256) {
        return _interactionCount[agent];
    }

    function registerAgent(address agent) external onlyAuthorised returns (bool) {
        // register agent
        _agents[agent] = true;
        // asign agent to lowest layer
        _assignments[_round][agent] = _layers[_currentVersion][0];
        // update the score of the agent
        _scores[_round][agent] += _rewards[_currentVersion][0];

        timeDiscountedFactors[agent] = _factors[_currentVersion][_assignments[_round][agent]];
        agentList.push(agent);
        
        emit RegisterAgent(agent);
        
        return true;
    }

    event RegisterAgent(address agent);

    // ####################
    // ### TCR CONTROLS ###
    // ####################

    function update(address agent, uint256 action) external onlyAuthorised returns (bool) {
        _scores[_round][agent] += _rewards[_currentVersion][action];

        // asignment in the current round
        uint assignment = getAssignment(agent);

        require(assignment > 0, "agent not assigned to layer");

        _interactionCount[agent] += 1;

        // promote the agent to the next layer
        if (_scores[_round][agent] >= _upper[_currentVersion][assignment] && assignment != _layers[_currentVersion].length) {
            // asignment in the next round
            _assignments[_round + 1][agent] = assignment + 1;
        // demote the agent to the previous layer
        } else if (_scores[_round][agent] <= _lower[_currentVersion][assignment] && assignment > 1) {
            // asignment in the next round
            _assignments[_round + 1][agent] = assignment - 1;
        // agent layer remans the same
        } else {
            _assignments[_round + 1][agent] = assignment;
        }
        
        emit Update(agent, _rewards[_currentVersion][action], _scores[_round][agent]);

        return true;
    }

    // function computeReward(uint256 action, uint256 amountInETH) private returns (uint256) {

    // }

    event Update(address agent, uint256 reward, uint256 score);

    function curate() public onlyAuthorised returns (bool) {
        require(_start != 0, "period not started");
        require(block.number >= _end, "period not ended");

        // update start and end times for next round
        _start = block.number;
        _end = block.number + _blockperiod;

        // switch to the next round
        _round++;

        updateTimeDiscountedFactors();

        emit Curate(_round, _start, _end);
        return true;
    }

    function updateTimeDiscountedFactors() private {
        for(uint i = 0; i < agentList.length; i++) {
            uint assignment = getAssignment(agentList[i]);
            timeDiscountedFactors[agentList[i]] = (_factors[_currentVersion][assignment] * recentFactorTimeDiscount + timeDiscountedFactors[agentList[i]] * olderFactorTimeDiscount) / (10 ** _decimals);
        }
    }

    event Curate(uint256 round, uint256 start, uint256 end);
}