// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./ERC721A.sol";
import "./Ownable.sol";

contract BatchNFTs is Ownable, ERC721A {
    uint256 public constant pricePerToken = 0.01 ether;
    uint256 public commissionFees = 0.001 ether;
    uint256 public startTime; // with respect to the presale
    uint256 public duration = 259200; // 3 days of presale 
    string private _baseTokenURI;
    uint256 public tokenId;
    address payable contractOwner = payable(owner());

    // Enum to specify the categories of an NFT
    enum Category {
        Premium,
        Normal
    }

    //The structure to store info about a listed token
    struct ListedToken {
        uint256 tokenId;
        address payable owner;
        address payable lastOwner;
        uint256 price;
        uint256 royalty;
        Category category;
    }

    // maps tokenId to the token details, used to retrieve the token details of a NFT
    mapping(uint256 => ListedToken) public idToListedToken;
    // maps tokenId to the token URI of the NFT
    mapping(uint256 => string) private tokenURIs;
    // maps tokenId to the original creator of the NFT
    mapping(uint256 => address) public originalCreators;
    // maps tokenId to the royalty fees of the original creator
    mapping(uint256 => uint256) public royaltyFees;
    // maps tokenId to the initial sale price of the NFT
    mapping(uint256 => uint256) public salePrices;
    // maps tokenId to the boolean showing whether the NFT is on sale or not
    mapping(uint256 => bool) public isNFTForSale;

    constructor() ERC721A("Test", "TT") {}

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // Set token URI
    function setTokenURI(uint256 _tokenId, string memory _tokenURI) internal {
        tokenURIs[_tokenId] = _tokenURI;
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {

        string memory _tokenURI = tokenURIs[_tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via string.concat).
        if (bytes(_tokenURI).length > 0) {
            return string.concat(base, _tokenURI);
        }

        return super.tokenURI(_tokenId);
    }
    // Function to set the commission fees
    function setCommissionFees(uint256 newCommissionFees) public onlyOwner {
        require(newCommissionFees < pricePerToken * 5 / 10, "New commission price is very high");
        commissionFees = newCommissionFees;
    }

    // Mint new NFT ----->approval for contract to transfer(sell)
    function mint(
        uint256 quantity,
        uint256 fees,
        Category batchCategory,
        string[] memory _tokenURIs
    ) public payable {
        require(_tokenURIs.length == quantity, "Number of token URIs doesn't match with the quantity of NFTs to be minted");
        _mint(msg.sender, quantity);
        uint256 endTokenId = tokenId + quantity;
        for (uint256 i = tokenId; i < endTokenId; i++) {
            uint256 _tokenId = i;

            for(uint256 j = 0; j < quantity; j++){
                tokenURIs[_tokenId] = _tokenURIs[j];
            }
            royaltyFees[_tokenId] = fees;
            // Update the mapping of tokenId to the NFT minter
            originalCreators[_tokenId] = msg.sender;
            // Update the mapping of tokenId's to Token details
            idToListedToken[_tokenId] = ListedToken(
                _tokenId,
                payable(msg.sender), // owner
                payable(address(0)), // last owner
                pricePerToken,
                fees, // royalty fees
                batchCategory
            );

            approve(address(this), i);
        }
        tokenId = endTokenId;
    }

    // to update the presale duration and start 
    function updatePresaleTime(
        uint256 _startTime,
        uint256 _duration
    ) internal onlyOwner {
        require(_startTime > block.timestamp + 3600, "Presale can be started only after an hour");
        startTime = _startTime;
        duration = _duration;
    }
    
    // Presale of newly minted NFTs only
    function presale(uint256 _tokenId) public payable {
        require(block.timestamp >= startTime, "Sale not started");
        require(block.timestamp <= startTime + duration, "Sale has ended");
        uint256 presalePrice = pricePerToken * 8 / 10; // ----> use maps openzeppelin
        require(
            msg.value == presalePrice && msg.value > commissionFees,
            "Please submit the asking price in order to complete the purchase"
        );
        require(idToListedToken[_tokenId].lastOwner == address(0), "Token already sold, not under presale");

        
        address payable seller = idToListedToken[_tokenId].owner;
        // transfer the token to the new owner - from, to, tokenId
        transferFrom(seller, msg.sender, _tokenId);

        // -----> for different tokens, IERC20 contract needs to be inherited + real time conversion of tokens

        // Transfer commission to the contract owner
        (bool commissionTransferSuccess, ) = contractOwner.call{value: commissionFees}("");
        require(commissionTransferSuccess, "Failed to send commission");

        // Transfer remaining amount to the seller
        uint256 remainingAmount = msg.value - commissionFees;
        (bool remainingAmountTransferSuccess, ) = payable(seller).call{value: remainingAmount}("");
        require(remainingAmountTransferSuccess, "Failed to send remaining amount");
        
        //update the details of the token
        idToListedToken[_tokenId].owner = payable(msg.sender);
        idToListedToken[_tokenId].lastOwner = seller;
    }

    // Listing NFT open for resell
    function listNFTForSale(uint256 _tokenId, uint256 _salePrice) public {
        require(_exists(_tokenId), "Token does not exists");
        salePrices[tokenId] = _salePrice;
        isNFTForSale[tokenId] = true;
    }
    // -------> enum for token status i.e. number of times reselled
    function resell(uint256 _tokenId) public payable {
        require(isNFTForSale[_tokenId], "Token is not for sale");
        require(idToListedToken[_tokenId].lastOwner != address(0), "NFT is freshly minted and has not been sold yet");
        require(msg.value == salePrices[_tokenId], "Please submit the asking price in order to complete the purchase");
        
        address payable seller = idToListedToken[_tokenId].owner;
        // transfer the token to the new owner - from, to, tokenId
        transferFrom(seller, msg.sender, _tokenId);

        // Transfer commission to the contract owner
        (bool commissionTransferSuccess, ) = contractOwner.call{value: commissionFees}("");
        require(commissionTransferSuccess, "Failed to send commission fees");

        // Transfer royalty fees to the artist
        (bool royaltyTransferSuccess, ) = payable(originalCreators[_tokenId]).call{value: royaltyFees[_tokenId]}("");
        require(royaltyTransferSuccess, "Failed to send royalty fees");
        // Transfer remaining amount to the seller
        uint256 remainingAmount = msg.value - commissionFees - royaltyFees[_tokenId];
        (bool remainingAmountTransferSuccess, ) = payable(seller).call{value: remainingAmount}("");
        require(remainingAmountTransferSuccess, "Failed to send remaining amount");
        
        //update the details of the token
        idToListedToken[_tokenId].owner = payable(msg.sender);
        idToListedToken[_tokenId].lastOwner = seller;
    }

    // View functions
    function getListedTokenForId(
        uint256 _tokenId
    ) public view returns (ListedToken memory) {
        return idToListedToken[_tokenId];
    }

    function getRoyaltyFees(uint256 _tokenId) public view returns (uint256) {
        require(_exists(_tokenId), "Token does not exist");
        return royaltyFees[_tokenId];
    }

    function saleTimeLeft() public view returns (uint256 timeLeft) {
        timeLeft = startTime + duration - block.timestamp;
    }
    
    // This will return all the NFTs currently listed to be sold on the marketplace
    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint nftCount = tokenId;
        ListedToken[] memory tokens = new ListedToken[](nftCount);
        uint currentIndex = 0;
        uint currentId;
        // at the moment currentlyListed is true for all, if it becomes false in the future we will
        // filter out currentlyListed == false over here
        for (uint i = 0; i < nftCount; i++) {
            currentId = i + 1;
            ListedToken storage currentItem = idToListedToken[currentId];
            tokens[currentIndex] = currentItem;
            currentIndex += 1;
        }
        // the array 'tokens' has the list of all NFTs in the marketplace
        return tokens;
    }

    //Returns all the NFTs that the current user is owner or seller in
    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint totalItemCount = tokenId;
        uint itemCount = 0;
        uint currentIndex = 0;
        uint currentId;
        // Important to get a count of all the NFTs that belong to the user before we can make an array for them
        for (uint i = 0; i < totalItemCount; i++) {
            if (
                idToListedToken[i + 1].owner == msg.sender ||
                idToListedToken[i + 1].lastOwner == msg.sender
            ) {
                itemCount += 1;
            }
        }

        // Once you have the count of relevant NFTs, create an array then store all the NFTs in it
        ListedToken[] memory items = new ListedToken[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (
                idToListedToken[i + 1].owner == msg.sender ||
                idToListedToken[i + 1].lastOwner == msg.sender
            ) {
                currentId = i + 1;
                ListedToken storage currentItem = idToListedToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
}
