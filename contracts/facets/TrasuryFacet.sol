pragma solidity ^0.8.0;

import { LibDiamond } from  "../libraries/LibDiamond.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface Governor{
    function getForVoters(uint256 proposalId) external view returns(address[] memory);
    function getAgainstVoters(uint256 proposalId) external view returns(address[] memory);
    function forPower(uint256 proposalId) external view returns(uint256);
    function againstPower(uint256 proposalId) external view returns(uint256);
    function againstWeights(uint256 proposalId) external view returns(uint256[] memory);
    function forWeights(uint256 proposalId) external view returns(uint256[] memory);
}

contract TreasuryFacet{

    function setBudget(uint256 _newBudget) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(msg.sender == ds.contractOwner);
        require((ds.treasury * 30 / 100) >= _newBudget);
        require(block.timestamp >= ds.period);
        ds.budget = _newBudget;
        ds.period = block.timestamp + 60 days;
    }

    function transfer(address _to, uint256 _amount) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(msg.sender == ds.contractOwner);
        require(_amount <= ds.budget);
        require(_to != address(0x00));
        payable(_to).transfer(_amount);
    }

    function beforeProposal(uint256 _proposalid, uint256 _currentPrice) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(ds.governor == msg.sender);
        ds.beforeProposal[_proposalid] = _currentPrice;
    }


    // receive the proposalid and the price of CAT/Matic(how many Matics is used to buy a CAT)
    function payout(uint256 _proposalid, uint256 _currentPrice) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(ds.governor == msg.sender);

        // if current price is grater than or equal the previous price after proposal approval
        //  who votes for will receive part of the free treasury base on his token amount
        if(ds.beforeProposal[_proposalid] < _currentPrice || ds.beforeProposal[_proposalid] < _currentPrice){
            Governor gov = Governor(ds.governor);
            address[] memory forVoters = gov.getForVoters(_proposalid);
            uint256[] memory forWeights = gov.forWeights(_proposalid);
            require(forVoters.length == forWeights.length);
            uint256 totalPower = gov.forPower(_proposalid);
            for(uint256 i; i < forVoters.length; i++){
                uint256 percent = forWeights[i] * 100 / totalPower;
                uint256 prize = (ds.treasury * 70 / 100) * percent / 100;
                ds.treasury -= prize;
                ds.dividends[forVoters[i]] += prize; 
            }

        } else if(ds.beforeProposal[_proposalid] > _currentPrice) {
            // who votes against will receive part of the free trasury based on his token amount
            Governor gov = Governor(ds.governor);
            address[] memory againstVoters = gov.getAgainstVoters(_proposalid);
            uint256[] memory againstWeights = gov.againstWeights(_proposalid);
            require(againstVoters.length == againstWeights.length);
            uint256 totalPower = gov.againstPower(_proposalid);
            for(uint256 i; i < againstVoters.length; i++){
                uint256 percent = againstWeights[i] * 100 / totalPower;
                uint256 prize = (ds.treasury * 70 / 100) * percent / 100;
                ds.treasury -= prize;
                ds.dividends[againstVoters[i]] += prize; 
            }
        }
    }

    function withdrawDividends() external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 amount = ds.dividends[msg.sender];
        require(amount > 0);
        ds.dividends[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }
}