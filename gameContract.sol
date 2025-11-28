// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract VersaGames is Ownable, ReentrancyGuard {
    
    uint256 public stakeAmount;
    uint256 public currentRound;
    uint256 public totalGamesPlayed;
    
    struct Round {
        uint256 prizePool;
        uint256 playerCount;
        bool isActive;
        bool prizeClaimed;
        address winner;
    }
    
    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(address => bool)) public hasPlayedInRound;
    mapping(uint256 => address[]) public roundPlayers;
    
    event GamePlayed(address indexed player, uint256 round, uint256 amount, uint256 timestamp);
    event RoundStarted(uint256 indexed round, uint256 stakeAmount);
    event RoundEnded(uint256 indexed round, address indexed winner, uint256 prize);
    event PrizePoolFunded(uint256 indexed round, uint256 amount);
    
    constructor(uint256 _initialStakeAmount) Ownable(msg.sender) {
        require(_initialStakeAmount > 0, "Stake amount must be greater than 0");
        stakeAmount = _initialStakeAmount;
        _startNewRound();
    }
    
    function playGame() external payable nonReentrant {
        require(msg.value == stakeAmount, "Incorrect stake amount");
        require(rounds[currentRound].isActive, "Round not active");
        require(!hasPlayedInRound[currentRound][msg.sender], "Already played in this round");
        
        hasPlayedInRound[currentRound][msg.sender] = true;
        roundPlayers[currentRound].push(msg.sender);
        rounds[currentRound].playerCount++;
        rounds[currentRound].prizePool += msg.value;
        totalGamesPlayed++;
        
        emit GamePlayed(msg.sender, currentRound, msg.value, block.timestamp);
    }
    
    function fundPrizePool() external payable onlyOwner {
        require(msg.value > 0, "Must send ETH to fund the prize pool");
        require(rounds[currentRound].isActive, "No active round");
        rounds[currentRound].prizePool += msg.value;
        emit PrizePoolFunded(currentRound, msg.value);
    }
    
    // Owner selects winner (you fit add Chainlink VRF for true randomness)
    function selectWinner(address winner) external onlyOwner nonReentrant {
        require(rounds[currentRound].isActive, "Round not active");
        require(hasPlayedInRound[currentRound][winner], "Winner must have played");
        require(rounds[currentRound].playerCount > 0, "No players in round");
        require(!rounds[currentRound].prizeClaimed, "Prize already claimed");
        
        uint256 prize = rounds[currentRound].prizePool;
        rounds[currentRound].isActive = false;
        rounds[currentRound].winner = winner;
        rounds[currentRound].prizeClaimed = true;
        rounds[currentRound].prizePool = 0;
        
        payable(winner).transfer(prize);
        
        emit RoundEnded(currentRound, winner, prize);
    }
    
    function startNewRound() external onlyOwner {
        require(!rounds[currentRound].isActive, "Current round still active");
        _startNewRound();
    }
    
    function _startNewRound() private {
        currentRound++;
        rounds[currentRound].isActive = true;
        emit RoundStarted(currentRound, stakeAmount);
    }
    
    function updateStakeAmount(uint256 _newStakeAmount) external onlyOwner {
        require(!rounds[currentRound].isActive, "Cannot change stake during active round");
        require(_newStakeAmount > 0, "Stake amount must be greater than 0");
        stakeAmount = _newStakeAmount;
    }
    
    // View functions
    function getCurrentPrizePool() external view returns (uint256) {
        return rounds[currentRound].prizePool;
    }
    
    function getRoundPlayers(uint256 round) external view returns (address[] memory) {
        return roundPlayers[round];
    }
    
    function getCurrentRoundPlayers() external view returns (address[] memory) {
        return roundPlayers[currentRound];
    }
    
    function getRoundInfo(uint256 round) external view returns (
        uint256 prizePool,
        uint256 playerCount,
        bool isActive,
        bool prizeClaimed,
        address winner
    ) {
        Round memory r = rounds[round];
        return (r.prizePool, r.playerCount, r.isActive, r.prizeClaimed, r.winner);
    }
}
