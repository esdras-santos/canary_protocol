//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { LibDiamond } from  "../libraries/LibDiamond.sol";
import "hardhat/console.sol";

interface ERC721Metadata{
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}

interface CanaryToken{
    function mint(address _platform, uint256 _amount) external;
    function burn(address _platform, uint256 _amount) external;
}

contract CanaryFacet {

    event GetRight(uint256 indexed _rightid, uint256 indexed _period, address indexed _who);
    event DepositedNFT(address indexed _erc721, uint256 indexed _nftid);

    modifier isNFTOwner(uint256 _rightid){
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(ds.owner[_rightid] == msg.sender, "only the NFT Owner");
        _;
    }

    function getRights(uint256 _rightid, uint256 _period) external payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(ds.isAvailable[_rightid],"NFT is not available");
        require(ds.maxtime[_rightid] >= _period,"period is above the max period");
        require(msg.value >= (ds.dailyPrice[_rightid] * _period), "value is less than the required");
        require(ds.maxRightsHolders[_rightid] > 0, "limit of right holders reached");
        require(ds.rightsPeriod[_rightid][msg.sender] == 0,"already buy this right");
        require(_period > 0, "period is equal to 0");
        // take 5% of the right amount as fee
        ds.maxRightsHolders[_rightid] = ds.maxRightsHolders[_rightid] - 1;
        ds.treasury += msg.value * 500 / 10000;
        
        ds.rightsPeriod[_rightid][msg.sender] = _period;
        ds.rightsOver[msg.sender].push(_rightid);
        ds.deadline[_rightid][msg.sender] = block.timestamp + (1 days * _period);
        
        if(block.timestamp + (1 days * _period) > ds.highestDeadline[_rightid]){
            ds.highestDeadline[_rightid] = block.timestamp + (1 days * _period);
        }
        ds.rightHolders[_rightid].push(msg.sender);
        
        emit GetRight(_rightid, _period, msg.sender);
    }

    // need to call approval before calling this function
    function depositNFT(
        address _erc721, 
        uint256 _nftid, 
        uint256 _dailyPrice, 
        uint256 _maxPeriod,
        uint256 _amount) 
        external 
    {
        require(_erc721 != address(0x00), "collection address is zero");
        ERC721Metadata e721metadata = ERC721Metadata(_erc721);
        string memory uri = e721metadata.tokenURI(_nftid);
        _mint(_erc721, _nftid, _amount, _dailyPrice, _maxPeriod, uri);
        IERC721 e721 = IERC721(_erc721);
        e721.transferFrom(msg.sender, address(this), _nftid);
        emit DepositedNFT(_erc721, _nftid);
    }

    function withdrawRoyalties(
        uint256 _rightid, 
        address[] memory _deadlinelist,
        uint256[] memory _roindexes,
        uint256[] memory _rhindexes) 
        external isNFTOwner(_rightid)
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 amountToWithdraw = 0;
        for(uint256 i; i < _deadlinelist.length; i++){
            require(ds.deadline[_rightid][_deadlinelist[i]] < block.timestamp, "NFT do not exceeded the deadline yet");
            require(ds.rightsOver[_deadlinelist[i]][_roindexes[i]] == _rightid, "wrong index for rightid");
            require(ds.rightHolders[_rightid][_rhindexes[i]] == _deadlinelist[_deadlinelist.length-1-i],"right holder address and deadline list address is not equal");
            require(ds.deadline[_rightid][_deadlinelist[i]] > 0, "NFT deadline needs to be above zero");

            uint256 amount = (ds.dailyPrice[_rightid] * ds.rightsPeriod[_rightid][_deadlinelist[i]]);
            // subtract the fee
            amountToWithdraw += amount - (amount * 500 / 10000);
            
            ds.rightsOver[_deadlinelist[i]][_roindexes[i]] = ds.rightsOver[_deadlinelist[i]][ds.rightsOver[_deadlinelist[i]].length -1];
            ds.rightsOver[_deadlinelist[i]].pop();
            
            ds.rightHolders[_rightid][_rhindexes[i]] = ds.rightHolders[_rightid][ds.rightHolders[_rightid].length -1];
            ds.rightHolders[_rightid].pop();

            ds.deadline[_rightid][_deadlinelist[i]] = 0;
            ds.rightsPeriod[_rightid][_deadlinelist[i]] = 0;

            ds.maxRightsHolders[_rightid] = ds.maxRightsHolders[_rightid] + 1;

        }
        payable(msg.sender).transfer(amountToWithdraw);
    }

    function withdrawNFT(uint256 _rightid, uint256 _rightIndex) external isNFTOwner(_rightid) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(ds.highestDeadline[_rightid] < block.timestamp, "highest right deadline should end before withdraw");
        require(ds.isAvailable[_rightid] == false, "NFT should be unavailable");
        require( ds.properties[msg.sender][_rightIndex] == _rightid, "wrong index for collection address");
        address erc721 = address(uint160(uint256(ds.rightsOrigin[_rightid][0])));
        uint256 nftid = uint256(ds.rightsOrigin[_rightid][1]);
        _burn(_rightid, _rightIndex);
        ds.highestDeadline[_rightid] = 0;
        IERC721 e721 = IERC721(erc721);
        e721.transferFrom(address(this), msg.sender, nftid);
    }

    function setAvailability( 
        uint256 _rightid, 
        bool _available, 
        uint256 _nftindex) 
        external isNFTOwner(_rightid) 
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if(ds.isAvailable[_rightid] == true){
            require(ds.availableRights[_nftindex] == _rightid, "wrong index for rightid");
        }
        if(_available == false){
            ds.availableRights[_nftindex] = ds.availableRights[ds.availableRights.length - 1];
            ds.availableRights.pop();
        } else {
            ds.availableRights.push(_rightid);
        }
        ds.isAvailable[_rightid] = _available;
    }

    function verifyRight(uint256 _rightid, address _platform) external{
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(ds.rightsPeriod[_rightid][_platform] == 0, "the platform cannot be the right holder");
        require(ds.rightsPeriod[_rightid][msg.sender] > 0, "sender is not the right holder");
        require(ds.deadline[_rightid][msg.sender] > block.timestamp,"has exceeded the right time");
        require(ds.validated[_rightid][_platform][msg.sender] == false, "rightid and right holder are already validated");
        ds.validated[_rightid][_platform][msg.sender] = true;
        CanaryToken ct = CanaryToken(ds.governanceToken);
        ct.mint(_platform, ds.dailyPrice[_rightid]/2);
    }

    function verified(uint256 _rightid, address _platform) external view returns(bool){
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.validated[_rightid][_platform][msg.sender];
    }

    function _mint(
        address _erc721, 
        uint256 _nftid, 
        uint256 _amount,
        uint256 _dailyPrice,
        uint256 _maxPeriod, 
        string memory _nftUri) 
        internal 
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 rightid = uint256(keccak256(abi.encode(_erc721, _nftid)));
        ds.maxRightsHolders[rightid] = _amount;
        ds.dailyPrice[rightid] = _dailyPrice;
        ds.maxtime[rightid] = _maxPeriod;
        ds.owner[rightid] = msg.sender;
        ds.rightsOrigin[rightid].push(bytes32(uint256(uint160(_erc721))));
        ds.rightsOrigin[rightid].push(bytes32(_nftid));
        ds.rightUri[rightid] = _nftUri;
        ds.isAvailable[rightid] = true;
        ds.properties[msg.sender].push(rightid);
        ds.availableRights.push(rightid);
    }

    function _burn(uint256 _rightid, uint256 _rightIndex) internal{
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.maxRightsHolders[_rightid] = 0;
        ds.dailyPrice[_rightid] = 0;
        ds.maxtime[_rightid] = 0;
        ds.rightsOrigin[_rightid].pop();
        ds.rightsOrigin[_rightid].pop();
        ds.properties[msg.sender][_rightIndex] = ds.properties[msg.sender][ds.properties[msg.sender].length - 1];
        ds.properties[msg.sender].pop();
        ds.rightUri[_rightid] = "";
        ds.owner[_rightid] = address(0x00);
    }

    function setGovernanceToken(address _newToken) external{
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(ds.contractOwner == msg.sender);
        ds.governanceToken = _newToken;
    }

    function currentTreasury() external view returns (uint256){
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.treasury;
    }

    function dailyPriceOf(uint256 _rightid) external view returns (uint256) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.dailyPrice[_rightid];
    }

    function availableRightsOf(uint256 _rightid) external view returns (uint256) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.maxRightsHolders[_rightid];
    }

    function maxPeriodOf(uint256 _rightid) external view returns (uint256) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.maxtime[_rightid];
    }

    function rightsPeriodOf(uint256 _rightid, address _holder) external view returns (uint256){
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.rightsPeriod[_rightid][_holder];
    }

    function rightsOf(address _rightsHolder) external view returns (uint256[] memory) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.rightsOver[_rightsHolder];
    }

    function propertiesOf(address _owner) external view returns (uint256[] memory) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.properties[_owner];
    }

    function getAvailableNFTs() external view returns (uint256[] memory) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.availableRights;
    }

    function rightHoldersOf(uint256 _rightid) external view returns (address[] memory){
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.rightHolders[_rightid];
    }

    function holderDeadline(uint256 _rightid, address _holder) external view returns (uint256){
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.deadline[_rightid][_holder];
    }

    function ownerOf(uint256 _rightid) external view returns (address){
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.owner[_rightid];
    }

    function availabilityOf(uint256 _rightid) external view returns (bool){
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.isAvailable[_rightid];
    }

    function rightURI(uint256 _rightid) external view returns (string memory){
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.rightUri[_rightid];
    }

    function originOf(uint256 _rightid) external view returns (bytes32[] memory){
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.rightsOrigin[_rightid];
    }
}
