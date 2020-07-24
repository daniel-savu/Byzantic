pragma solidity ^0.5.0;

// import "./InitializableAdminUpgradeabilityProxy.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@nomiclabs/buidler/console.sol";
import "./ILBCR.sol";

contract LBCR is Ownable, ILBCR {
    address[] authorisedContracts;

    uint256 _decimals; // decimals to calculate collateral factor

    // Implementation of L = (lower, upper, factor)
    uint[] _layers; // array of layers, e.g. {1,2,3,4}
    mapping (uint => uint256) _lower; // lower bound of layer
    mapping (uint => uint256) _upper; // upper bound of layer
    mapping (uint => uint256) _factors; // factor of layer

    // Implementation of the relevant agreement parameters A = (phi, payment, score, deposits)
    mapping (uint256 => uint256) _rewards; // reward (score) for performing an action

    // Implementation of the registry
    mapping (uint256 => mapping (address => uint)) _assignments; // layer assignment by round and agent
    mapping (uint256 => mapping (address => uint256)) _scores; // score by round and agent
    mapping (address => uint256) _interactionCount;
    uint256 _round; // current round in the protocol
    
    mapping (address => bool) _agents; // track all agents
    address[] agentList;

    uint256 _blockperiod; // block period until curation
    uint256 _start; // start of period
    uint256 _end; // end of period
    mapping(address => uint) compatibilityScores;
    mapping(address => uint) timeDiscountedFactors;

    uint recentFactorTimeDiscount;
    uint olderFactorTimeDiscount;



    constructor() public {
        // addAuthorisedContract(msg.sender);
        _decimals = 3; // e.g. a factor of 1500 is equal to 1.5 times the collateral
        _round = 0; // init rounds
        
        _blockperiod = 1; // wait for 1 block to curate
        _start = block.number;
        _end = block.number + _blockperiod;

        recentFactorTimeDiscount = 400;
        olderFactorTimeDiscount = 600;
    }

    function addAuthorisedContract(address authorisedContract) public onlyAuthorised {
        authorisedContracts.push(authorisedContract);
    }

    modifier onlyAuthorised() {
        // bool isAuthorised = false;
        // if(isOwner()) {
        //     isAuthorised = true;
        // }
        // for (uint i = 0; i < authorisedContracts.length; i++) {
        //     if(authorisedContracts[i] == msg.sender) {
        //         isAuthorised = true;
        //         break;
        //     }
        // }
        // require(isAuthorised == true, "Caller is not authorised to perform this action");
        _;
    }

    function getCompatibilityScoreWith(address protocol) external view returns (uint256) {
        if(protocol == address(this)) {
            return 100;
        }
        return compatibilityScores[protocol];
    }

    function setCompatibilityScoreWith(address protocol, uint256 score) external {
        compatibilityScores[protocol] = score;
    }
    
    // ##############
    // ### LAYERS ###
    // ##############

    function getLayers() public view returns(uint[] memory) {
        return _layers;
    }

    function setLayers(uint8[] memory layers) public {
         // set layers
        _layers = layers;
    }

    function resetLayers() public {
        delete _layers;
    }

    function addLayer(uint layer) public {
        _layers.push(layer);
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
        return _factors[layer];
    }

    function setFactor(uint layer, uint256 factor) public onlyAuthorised returns (bool) {
        // require(factor >= (10 ** _decimals), "factor needs to be above or equal to 1.0");
        // require(layer > 0, "layer 0 is reserved");
        _factors[layer] = factor;
        return true;
    }

    // ###############
    // ### REWARD ###
    // ###############

    function getReward(uint256 action) public view returns (uint256) {
        return _rewards[action];
    }

    function setReward(uint256 action, uint256 reward) public onlyAuthorised returns (bool) {
        _rewards[action] = reward;
        return true;
    }

    // ###############
    // ### BOUNDS ###
    // ###############

    function getBounds(uint layer) public view returns (uint256, uint256) {
        return (_lower[layer], _upper[layer]);
    }

    function setBounds(uint layer, uint256 lower, uint256 upper) public onlyAuthorised returns (bool) {
        _lower[layer] = lower;
        _upper[layer] = upper;

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
                for (uint i = 1; i < _layers.length && i < _round; i++) {
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

    function registerAgent(address agent) public returns (bool) {
        // register agent
        _agents[agent] = true;
        // asign agent to lowest layer
        _assignments[_round][agent] = _layers[0];
        // update the score of the agent
        _scores[_round][agent] += _rewards[0];

        timeDiscountedFactors[agent] = _factors[_assignments[_round][agent]];
        agentList.push(agent);
        
        emit RegisterAgent(agent);
        
        return true;
    }

    event RegisterAgent(address agent);

    // ####################
    // ### TCR CONTROLS ###
    // ####################

    function update(address agent, uint256 action) public returns (bool) {
        _scores[_round][agent] += _rewards[action];

        // asignment in the current round
        uint assignment = getAssignment(agent);

        require(assignment > 0, "agent not assigned to layer");

        _interactionCount[agent] += 1;

        // promote the agent to the next layer
        if (_scores[_round][agent] >= _upper[assignment] && assignment != _layers.length) {
            // asignment in the next round
            _assignments[_round + 1][agent] = assignment + 1;
        // demote the agent to the previous layer
        } else if (_scores[_round][agent] <= _lower[assignment] && assignment > 1) {
            // asignment in the next round
            _assignments[_round + 1][agent] = assignment - 1;
        // agent layer remans the same
        } else {
            _assignments[_round + 1][agent] = assignment;
        }
        
        emit Update(agent, _rewards[action], _scores[_round][agent]);

        return true;
    }

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
            timeDiscountedFactors[agentList[i]] = (_factors[assignment] * recentFactorTimeDiscount + timeDiscountedFactors[agentList[i]] * olderFactorTimeDiscount) / (10 ** _decimals);
        }
    }

    event Curate(uint256 round, uint256 start, uint256 end);
}