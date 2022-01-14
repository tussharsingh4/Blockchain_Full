//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";




contract TokenFarm is Ownable{
    //mapping token address-> staker address ->amount
    mapping(address => mapping(address => uint256)) public stakingBalance;
    mapping(address => uint256) public uniqueTokensStaked;
    mapping(address => address) public tokenPriceFeedMapping;

// 100 eth  1:1 we give 1 dapp token
// 50 eth and 50 dai and we want to give a reward of 1 dapp/1 dai

    address[] public allowedTokens;
    address[] public stakers;
    IERC20 public dappToken;

    constructor(address _dappTokenAddress) public {
        dappToken = IERC20(_dappTokenAddress);
    }

    function setPriceFeedContract(address _token, address _priceFeed) public onlyOwner {
        tokenPriceFeedMapping[_token] = _priceFeed;
    }

    function issueTokens() public onlyOwner {

        for(uint256 stakersIndex=0; stakersIndex< stakers.length; stakersIndex++){
            address recipient = stakers[stakersIndex];
            uint256 userTotalValue = getUserTotalValue(recipient);

            dappToken.transfer(recipient, userTotalValue);
            //send them a token reward based on their total value locked
        }
    }

    function getUserTotalValue(address _user) public view returns(uint256) {
        uint256 totalValue =0;
        require(uniqueTokensStaked[_user]>0 , "No tokens Staked!");

        for(uint256 allowedTokensIndex=0; allowedTokensIndex < allowedTokens.length; allowedTokensIndex++){
            totalValue = totalValue + getUserSingleTokenValue(_user, allowedTokens[allowedTokensIndex]);
        }
        return totalValue;
    }

    function getUserSingleTokenValue(address _user, address _token) public view returns(uint256){
        if(uniqueTokensStaked[_user]<=0){
            return 0;
        }
        //price of token*stakingBalace[_token][_user]

        (uint256 price, uint256 decimals) = getTokenValue(_token);

        return (stakingBalance[_token][_user]*price / 10**decimals);
        //100000000000000000 eth
        //eth/usd -> 100000000
        //10*100 = 1000

    }// we dont want it to revert so we are not doing any require here

    function getTokenValue(address _token) public view returns(uint256, uint256){
        address priceFeedAddress = tokenPriceFeedMapping[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        (, int256 price,,,) = priceFeed.latestRoundData();
        uint256 decimals  = uint256(priceFeed.decimals());
        return(uint256(price), decimals);
    }


    function stakeTokens(uint256 _amount, address _token) public {
        // what tokens can be staked and how much can be
        require (_amount>0, "Amount must be more than 0");
        require (tokenIsAllowed(_token), "Token is currently not allowed");
        //transfer works when we own the token and if we dont own the token then we need to call transfer from function
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        stakingBalance [_token][msg.sender] = stakingBalance[_token][msg.sender]+ _amount;
        updateUniqueTokensStaked(msg.sender, _token);
        if(uniqueTokensStaked[msg.sender] == 1){
            stakers.push(msg.sender);
        }
    }

    function unstakeToken(address _token) public {
        uint256 balance = stakingBalance[_token][msg.sender];
        require(balance>0,"Staking balance cannot be zero");
        IERC20(_token).transfer(msg.sender, balance);
        stakingBalance[_token][msg.sender] = 0;
        uniqueTokensStaked[msg.sender] = uniqueTokensStaked[msg.sender]-1;
    }

    function addAllowedTokens(address _token) public onlyOwner{
        allowedTokens.push(_token);
    }

    function updateUniqueTokensStaked(address _user, address _token ) internal {
        if(stakingBalance[_token][_user] <= 0){
            uniqueTokensStaked[_user] = uniqueTokensStaked[_user]+1;
        }
    }

    function tokenIsAllowed(address _token) public returns (bool) {
        for(uint256 allowedTokensIndex=0; allowedTokensIndex < allowedTokens.length; allowedTokensIndex++){
            if (allowedTokens[allowedTokensIndex] == _token){
                return true;
            }
        }
        return false;
    }





}

//stake --done
//unstake
//issuetoken --done
//addAllowedtokens
//getEthvalue --done