// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "./ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Main contract for BatchNFTs
contract BatchNFTs is Ownable, ERC721A, ReentrancyGuard {
    // State variables
    uint256 public commissionFees;
    uint256 public startTime;
    uint256 public duration;
    uint256 public presaleDiscount; // Discount percentage for presale
    string private _baseTokenURI;

    // Enum for NFT categories
    enum Category {
        Premium,
        Normal
    }

    // Struct for listed tokens
    struct ListedToken {
        uint256 tokenId;
        address owner;
        address lastOwner;
        uint256 price;
        uint256 royalty;
        Category category;
        bool isForSale;
    }

    // Events
    event TokenHistory(uint256 tokenId, address owner, uint256 salePrice);
    event TokenUri(uint256 tokenId, string tokenUri);

    // Mappings
    mapping(address => bool) public canMint;
    mapping(address => bool) public moderator;
    mapping(Category => uint256) public pricePerTokenCategory;
    mapping(uint256 => ListedToken) public idToListedToken;
    mapping(uint256 => string) tokenURIs;
    mapping(uint256 => address) public originalCreators;

    // Modifiers
    modifier onlyArtist() {
        require(canMint[msg.sender], "Only artists are allowed to mint");
        _;
    }

    modifier onlyModerator() {
        require(
            moderator[msg.sender],
            "Only moderators are allowed to modify this function"
        );
        _;
    }

    // Constructor to initialize state variables
    constructor(uint256 _commissionFees, uint256 _duration)
        ERC721A("Azuki NFT", "AZUKI")
    {
        moderator[msg.sender] = true;
        canMint[msg.sender] = true;
        commissionFees = _commissionFees;
        duration = _duration;
        startTime = block.timestamp;
    }

    // Function to set a new moderator
    function setModerator(address _moderator) public onlyOwner {
        require(!moderator[_moderator], "Already a moderator");
        moderator[_moderator] = true;
    }

    // Function to set a new artist
    function setArtist(address _artist) public onlyModerator {
        require(!canMint[_artist], "Already an artist");
        canMint[_artist] = true;
    }

    // Function to set the base URI for tokens
    function setBaseURI(string calldata baseURI) external onlyModerator {
        _baseTokenURI = baseURI;
    }

    // Internal function to return the base URI
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // Internal function to set the token URI
    function setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        tokenURIs[tokenId] = _tokenURI;
        emit TokenUri(tokenId, _tokenURI);
    }

    // Function to change the commission fees
    function changeCommissionFees(uint256 newCommissionFees)
        public
        onlyModerator
    {
        commissionFees = newCommissionFees;
    }

    // Function to set the price per token category
    function setTokenPricebyCategory(Category category, uint256 categoryPrice)
        public
        onlyArtist
    {
        pricePerTokenCategory[category] = categoryPrice;
    }

    // Function to set the presale discount percentage
    function setPresaleDiscount(uint256 _presaleDiscount) public onlyOwner {
        require(_presaleDiscount < 100, "Discount cannot be 100% or more");
        presaleDiscount = _presaleDiscount;
    }

    // Function to mint new tokens
    function mint(
        uint256 quantity,
        uint256 fees,
        Category batchCategory,
        string[] memory _tokenURIs
    ) public onlyArtist nonReentrant {
        require(
            _tokenURIs.length == quantity,
            "Mismatch between URIs and quantity"
        );
        require(
            pricePerTokenCategory[batchCategory] > 0,
            "Category price not set"
        );

        uint256 price = pricePerTokenCategory[batchCategory];
        uint256 tokenId = totalSupply();
        _mint(msg.sender, quantity);

        for (uint256 i = 0; i < quantity; i++) {
            setTokenURI(tokenId, _tokenURIs[i]);
            originalCreators[tokenId] = msg.sender;
            idToListedToken[tokenId] = ListedToken(
                tokenId,
                msg.sender,
                address(0),
                price,
                fees,
                batchCategory,
                true
            );
            tokenId++;
        }
    }

    // Function to update the presale time
    function updatePresaleTime(uint256 _startTime, uint256 _duration)
        external
        onlyModerator
    {
        require(_startTime > block.timestamp, "Invalid start time");
        require(_duration > 0, "Duration must be greater than zero");
        startTime = _startTime;
        duration = _duration;
    }

    // Function to handle presale
    function presale(uint256 tokenId) public payable {
        require(
            block.timestamp >= startTime &&
                block.timestamp <= startTime + duration,
            "Not in presale period"
        );
        ListedToken storage listedToken = idToListedToken[tokenId];
        require(listedToken.lastOwner == address(0), "Token already sold");

        uint256 presalePrice = (listedToken.price * (100 - presaleDiscount)) /
            100;
        require(msg.value >= presalePrice, "Incorrect value sent");

        _handleSale(listedToken, presalePrice);
    }

    // Function to list a token for sale
    function listNFTForSale(uint256 tokenId, uint256 salePrice) public {
        require(_exists(tokenId), "Token does not exist");
        ListedToken storage listedToken = idToListedToken[tokenId];
        require(listedToken.owner == msg.sender, "Not the owner");

        listedToken.isForSale = true;
        listedToken.price = salePrice;
    }

    // Function to handle a sale
    function sale(uint256 tokenId) public payable {
        ListedToken storage listedToken = idToListedToken[tokenId];
        require(listedToken.isForSale, "Token not for sale");
        require(msg.value >= listedToken.price, "Incorrect value sent");

        _handleSale(listedToken, listedToken.price);
    }

    // Internal function to handle the sale logic
    function _handleSale(ListedToken storage listedToken, uint256 salePrice)
        internal
    {
        address payable seller = payable(listedToken.owner);
        internalTransfer(seller, msg.sender, listedToken.tokenId);

        payable(owner()).transfer(commissionFees);
        payable(originalCreators[listedToken.tokenId]).transfer(
            listedToken.royalty
        );

        uint256 remainingAmount = salePrice -
            commissionFees -
            listedToken.royalty;
        seller.transfer(remainingAmount);

        listedToken.owner = msg.sender;
        listedToken.lastOwner = seller;
        listedToken.price = salePrice;
        listedToken.isForSale = false;

        emit TokenHistory(listedToken.tokenId, msg.sender, salePrice);
    }

    // View token uri for of any token
    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
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

    // View function to get details of a listed token by its ID
    function getListedTokenForId(uint256 tokenId)
        public
        view
        returns (ListedToken memory)
    {
        return idToListedToken[tokenId];
    }

    // View function to get royalty fees for a specific token
    function getRoyaltyFees(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");
        return idToListedToken[tokenId].royalty;
    }

    // View function to check if the sale is active and how much time is left
    function saleActivity()
        public
        view
        returns (bool isActive, uint256 timeLeft)
    {
        if (
            block.timestamp > startTime &&
            block.timestamp < startTime + duration
        ) {
            isActive = true;
            timeLeft = startTime + duration - block.timestamp;
        } else {
            isActive = false;
            timeLeft = 0;
        }
    }

    // View function to get all NFTs owned by the caller
    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint256 totalItemCount = totalSupply();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        // Count NFTs owned by the caller
        for (uint256 i = 1; i <= totalItemCount; i++) {
            if (
                idToListedToken[i].owner == msg.sender ||
                idToListedToken[i].lastOwner == msg.sender
            ) {
                itemCount++;
            }
        }

        // Populate and return the result array
        ListedToken[] memory items = new ListedToken[](itemCount);
        for (uint256 i = 1; i <= totalItemCount; i++) {
            if (
                idToListedToken[i].owner == msg.sender ||
                idToListedToken[i].lastOwner == msg.sender
            ) {
                items[currentIndex] = idToListedToken[i];
                currentIndex++;
            }
        }
        return items;
    }
}
