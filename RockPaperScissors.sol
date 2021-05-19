// contracts/MyContract.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.0/contracts/utils/Counters.sol";

contract RockPaperScissors is Ownable{
    address tokenAddress; //Owner chooses what type of token is used
    uint bid; //minimum number of tokens required to play, set by the owner
    
    //Creating an IERC20 object globally saves gas over creating a new object in each function
    IERC20 token;
    
    //Counter allows users to play multiple games with anyone at anytime. 
    //since this game is asyncronous anyway, this is good design.
    using Counters for Counters.Counter;
    Counters.Counter private _gameIds;
    
    //optional fun double mapped state: 
    //map gameId => user => result code 
    //mapping (uint => mapping (address => uint8)) private gameStates;
    //0 = not played by this user, or in progress. 1 = this user wins, reward not claimed. 2 = this user lost. 3 = reward claimed, 
    //this could be more gas efficient by using keccak256(tokenId + address) => uint8, but it is much less readable. Personal choice
    
    
    //1 == Rock, 2 == Paper, 3 == Scissors 
    //maps game ids to user moves. Using 2 mappings is less gas intensive than creating a new object to store all the game info / moves together
    mapping(uint => uint8) private playerOneChoice;
    mapping(uint => address) private gameStarter;
    
    //Keep track of credits, so users can play with their winnings without having to redeem.
    mapping(address => uint) private _credits;
    
    
    event TokenAddressUpdated(address newTokenAdd);
    event GameStarted(uint gameId, address playerOne); //do not announce playerOne's move (pretend to keep this secret even though there is no secret data on chain)
    event GameOver(uint gameId, address winner, address loser);
    
    constructor(address _tokenAdd, uint _bid){
        tokenAddress = _tokenAdd;
        token = IERC20(_tokenAdd);
        
        bid = _bid;
    }
    
    function updateTokenAddress(address _tokenAdd) public onlyOwner{
        //I expect this function wont be called as often then others, so updating the IERC20 object here saves gas for users
        tokenAddress = _tokenAdd;
        token =  IERC20(_tokenAdd);

        emit TokenAddressUpdated(_tokenAdd);
    }
    
    function updateBid(uint _newBid) public onlyOwner{
        bid = _newBid;
    }
    
    /*
    * User function to start a new game
    * Alice can start a new game by putting up her bid (this contract must be allowed to spend bid amount of Alice's ERC20 tokens)
    * Anyone can play against Alice if they have the gameId, so she can send Bob the Id and tell him to play 
    * By allowing Alice to make her move while starting the match we eliminate the need for a primary deposit transaction, less transactions = better UX, and this also saves gas
    
    * Stretch: Funds will never be stuck in the contract, because anyone can play against Alice
    */
    function startGame(uint8 _move) public{
        require(_move < 4 && _move > 0);
        
        //Start by moving the deposit here. Will revert if bal not available.
        token.transferFrom(msg.sender, address(this), bid); //erc-20 function transfer(to, amount)
        
        _gameIds.increment();
        playerOneChoice[_gameIds.current()] = _move;
        
        gameStarter[_gameIds.current()] = msg.sender;
        
        //announce this game has started.
        emit GameStarted(_gameIds.current(), msg.sender);
    }
    
    //Stretch:
    //seperated credit functions since this will only be used something, and adding these checks would be more gas for normal GameStarted
    //lets you play with winnings from another game.
    function startGameWithCredit(uint8 _move) public{
        require(_move < 4 && _move > 0);
        
        //Start by using winning credit
        require(_credits[msg.sender] >= bid);
        _credits[msg.sender] -= bid;
        
        _gameIds.increment();
        playerOneChoice[_gameIds.current()] = _move;
        
        //announce this game has started.
        emit GameStarted(_gameIds.current(), msg.sender);
    }
    
    /* 
    * Bob or anyone can join the game by transfering tokens and throwing down. 
    * By playing at the same time as deposit, funds will never get stuck in the contract and gas is saved.
    */
    function playGame(uint _gameId, uint8 _move) public{
        require(_move < 4 && _move > 0);
        
        //Start by moving the deposit here. Will revert if bal not available.
        token.transferFrom(msg.sender, address(this), bid); //erc-20 function transfer(to, amount);
        
        //playerTwoChoice[_gameId] = _move; //this is unneeded, but might be a nice to have stored. We can save without it
        
        //rock 1 < paper 2
        //paper 2 < sci 3
        //sci 3 < rock 1
        if(playerOneChoice[_gameId] == 3 && _move == 1){
            //player 2 wins
            emit GameOver(_gameId, msg.sender, gameStarter[_gameId]);
            _credits[msg.sender] += 2*bid; 
        }
        else if(playerOneChoice[_gameId] < _move){
            //player 2 also wins 
            emit GameOver(_gameId, msg.sender, gameStarter[_gameId]);
            _credits[msg.sender] += 2*bid;
        }
        else{
            //player 1 wins
            emit GameOver(_gameId, gameStarter[_gameId], msg.sender);
            _credits[gameStarter[_gameId]] += 2*bid;
        }
        //match over.
    }
    
    //Stretch:
    //lets you play with winnings from another game.
    function playGameWithCredit(uint _gameId, uint8 _move) public{
        require(_credits[msg.sender] >= bid);
        _credits[msg.sender] -= bid;
        
        //rock 1 < paper 2
        //paper 2 < sci 3
        //sci 3 < rock 1
        if(playerOneChoice[_gameId] == 3 && _move == 1){
            //player 2 wins
            emit GameOver(_gameId, msg.sender, gameStarter[_gameId]);
            _credits[msg.sender] += 2*bid; 
        }
        else if(playerOneChoice[_gameId] < _move){
            //player 2 also wins 
            emit GameOver(_gameId, msg.sender, gameStarter[_gameId]);
            _credits[msg.sender] += 2*bid;
        }
        else{
            //player 1 wins
            emit GameOver(_gameId, gameStarter[_gameId], msg.sender);
            _credits[gameStarter[_gameId]] += 2*bid;
        }
    }
    
    function claimPrizes() public{
        token.transfer(msg.sender, _credits[msg.sender]);
        _credits[msg.sender] = 0;
    }
    
}
