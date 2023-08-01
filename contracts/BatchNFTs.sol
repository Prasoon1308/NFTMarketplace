// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./ERC721A.sol";
import "./Ownable.sol";

contract BatchNFTs is Ownable, ERC721A {
    uint256 public constant pricePerToken = 0.01 ether;
    uint256 public commissionFees = 0.001 ether;
    uint256 public startTime; // with respect to the presale
    uint256 public duration = 259200; // 3 days of presale --->can be updated fn(only owner)
    string private _baseTokenURI;
    uint256 public tokenId;

    // Enum to specify the categories of an NFT
    enum Category {
        Premium,
        Normal
    }

    //The structure to store info about a listed token
    struct ListedToken {
        uint256 tokenId;
        address payable owner;
        uint256 price;
        uint256 royalty;
        Category category;
    }

    // maps tokenId to the token details, used to retrieve the token details of a NFT
    mapping(uint256 => ListedToken) public idToListedToken;
    // maps tokenId to the royalty fees of the original creator
    mapping(uint256 => uint256) public royaltyFees;
    // maps tokenId to the original creator of the NFT
    mapping(uint256 => address) public originalCreators;

    constructor() ERC721A("Test", "TT") {}

    function updatePresaleTime(
        uint256 _startTime,
        uint256 _duration
    ) internal onlyOwner {
        startTime = _startTime;
        duration = _duration;
    }

    function mint(
        uint256 quantity,
        uint256 fees,
        Category batchCategory
    ) external payable {
        // require(block.timestamp >= startTime, "Sale not started");
        // require(block.timestamp <= startTime + duration, "Sale has ended"); ---presale (sell fn)
        // array of uri
        _mint(msg.sender, quantity);
        uint256 endTokenId = tokenId + quantity;
        for (uint256 i = tokenId; i < endTokenId; i++) {
            uint256 _tokenId = i;

            royaltyFees[_tokenId] = fees;
            // Update the mapping of tokenId to the NFT minter
            originalCreators[_tokenId] = msg.sender;
            // Update the mapping of tokenId's to Token details
            idToListedToken[_tokenId] = ListedToken(
                _tokenId,
                payable(msg.sender),
                pricePerToken,
                fees,
                batchCategory
            );
        }
        tokenId = endTokenId;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // Function to set the commission fees
    function setCommissionFees(uint256 newCommissionFees) external onlyOwner {
        commissionFees = newCommissionFees;
    }

    // View functions
    function getListedTokenForId(
        uint256 _tokenId
    ) public view returns (ListedToken memory) {
        return idToListedToken[_tokenId];
    }

    function getRoyaltyFees(uint256 _tokenId) external view returns (uint256) {
        require(_exists(_tokenId), "Token does not exist");
        return royaltyFees[_tokenId];
    }

    function saleTimeLeft() external view returns (uint256 timeLeft) {
        timeLeft = startTime + duration - block.timestamp;
    }
}
