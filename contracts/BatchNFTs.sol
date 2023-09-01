// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// contract address - 0x3085d1faA1Ed0DB1B851a7e49B99221e5A24B715
// contract address - 0xAf0281ECc867DE011203F652D8795a310F609f11
contract BatchNFTs is Ownable, ERC721A {
    uint256 public commissionFees = 0.001 ether;
    uint256 public startTime; // with respect to the presale
    uint256 public duration = 3600; // 1 hour of presale 
    string private _baseTokenURI;
    address public contractOwner;
    uint256 public _finalTokenId = _nextTokenId();

    // Enum to specify the categories of an NFT
    enum Category {
        Premium,
        Normal
    }

    //The structure to store info about a listed token
    struct ListedToken {
        uint256 tokenId;
        address owner;
        address lastOwner;
        uint256 price;
        uint256 royalty;
        Category category;
    }

    // Events for the write functions:
    event tokenHistory(uint256 _tokenId, address _owner, uint256 _salePrice);
    event tokenUri(uint256 _tokenId, string _tokenUri);

    // maps address to the boolean showing if the address has access to the mint function
    mapping(address => bool) public canMint;
    // maps address to the boolean showing if the address has access to some of the contract set functions
    mapping(address=>bool) public moderator;
    // maps to category enum  to the token price get token price category wise
    mapping(Category=>uint256) pricePerTokenCategory;
    // maps tokenId to the token details, used to retrieve the token details of a NFT
    mapping(uint256 => ListedToken) public idToListedToken;
    // maps tokenId to the token URI of the NFT
    mapping(uint256 => string) public tokenURIs;
    // maps tokenId to the original creator of the NFT
    mapping(uint256 => address) public originalCreators;
    // maps tokenId to the royalty fees of the original creator
    mapping(uint256 => uint256) public royaltyFees;
    // maps tokenId to the initial sale price of the NFT
    mapping(uint256 => uint256) public salePrices;
    // maps tokenId to the boolean showing whether the NFT is on sale or not
    mapping(uint256 => bool) public isNFTForSale;


    modifier onlyArtist(address _artist){
        require(canMint[_artist] == true, "Only artists are allowed to mint");
        _;
    }


    // moderator will be a multisig admin wallet
    modifier onlyModerator(address _moderator){
        require(moderator[_moderator] == true, "Only moderators are allowed to modify this function");
        _;
    }

    constructor() ERC721A("Test", "TT") {
        moderator[msg.sender] = true;
        contractOwner = msg.sender;
    }

    // Function to set the moderator for the contract
    function setModerator(address _moderator) public onlyOwner {
        moderator[_moderator] = true;
    }
    // Function to set the artists who can turn their art to an NFT
    function setArtist(address _artist) public onlyModerator(msg.sender) {
        canMint[_artist] = true;
    }

    function setBaseURI(string calldata baseURI) external onlyModerator(msg.sender) {
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
    // Function to change the commission fees
    function changeCommissionFees(uint256 newCommissionFees) public onlyModerator(msg.sender) {
        commissionFees = newCommissionFees;
    }
    // set category wise price ---> add onlyartist modifier
    function setTokenPricebyCategory(Category _category, uint256 _categoryPrice) public {
        pricePerTokenCategory[_category] = _categoryPrice;
    }

    // Mint new NFT ---> add onlyartist modifier
    function mint(
        uint256 quantity,
        uint256 fees,
        Category batchCategory,
        string[] memory _tokenURIs
    ) public payable {
        require(_tokenURIs.length == quantity, "Number of token URIs doesn't match with the quantity of NFTs to be minted");
        // Set the pricePerToken based on the selected category
        require(pricePerTokenCategory[batchCategory]>0, "Category price is not set yet");
        uint256 _price = pricePerTokenCategory[batchCategory];

        _mint(msg.sender, quantity);
        uint256 _index = 0;
        for (uint256 i = _finalTokenId; i < _finalTokenId + quantity; i++) {
            setTokenURI(i, _tokenURIs[_index]);
            emit tokenUri(i, _tokenURIs[_index]);
            _index++;
            royaltyFees[i] = fees;
            // Update the mapping of tokenId to the NFT minter
            originalCreators[i] = msg.sender;
            // Update the mapping of tokenId's to Token details
            idToListedToken[i] = ListedToken(
                i,
                msg.sender,
                address(0), // last owner
                _price,
                fees, // royalty fees
                batchCategory
            );
        }
        _finalTokenId = _finalTokenId + quantity;
    }

    // to update the presale duration and start
    function updatePresaleTime(
        uint256 _startTime,
        uint256 _duration
    ) external onlyModerator(msg.sender) {
        require(_startTime > block.timestamp + 10, "Presale can be started only after 10 sec");
        startTime = _startTime;
        duration = _duration;
    }
    
    // Presale of newly minted NFTs only 
    function presale(uint256 _tokenId) public payable {
        require(block.timestamp >= startTime, "Sale not started");
        require(block.timestamp <= startTime + duration, "Sale has ended");
        uint256 presalePrice = idToListedToken[_tokenId].price * 8 / 10;
        require(
            msg.value == presalePrice && msg.value > commissionFees,
            "Please submit the asking price in order to complete the purchase"
        );
        require(idToListedToken[_tokenId].lastOwner == address(0), "Token already sold, not under presale");

        
        address payable seller = payable(idToListedToken[_tokenId].owner);
        // transfer the token to the new owner - from, to, tokenId
        transferFrom(seller, msg.sender, _tokenId);

        // Transfer commission to the contract owner 
        (bool commissionTransferSuccess, ) = payable(contractOwner).call{value: commissionFees}("");
        require(commissionTransferSuccess, "Failed to send commission");

        // Transfer remaining amount to the seller
        uint256 remainingAmount = msg.value - commissionFees;
        (bool remainingAmountTransferSuccess, ) = payable(seller).call{value: remainingAmount}("");
        require(remainingAmountTransferSuccess, "Failed to send remaining amount");
        
        //update the details of the token
        idToListedToken[_tokenId].owner = payable(msg.sender);
        idToListedToken[_tokenId].lastOwner = seller;
        idToListedToken[_tokenId].price = presalePrice;
        emit tokenHistory(_tokenId, msg.sender, presalePrice);
    }

    function endOfPresale()public onlyArtist(msg.sender){
        require(!saleActivity(), "Presale is still ongoing");
        for(uint i = 0; i<_nextTokenId(); i++){
            if(idToListedToken[i].lastOwner == address(0)){
                isNFTForSale[i] = true;
                salePrices[i] = idToListedToken[i].price;
            }
        }
    }

    // Listing NFT open for resell
    function listNFTForSale(uint256 _tokenId, uint256 _salePrice) public {
        require(_exists(_tokenId), "Token does not exists");
        salePrices[_tokenId] = _salePrice;
        isNFTForSale[_tokenId] = true;
    }
    
    // sale of NFTs (resell + ones which were unsold in presale)
    function sale(uint256 _tokenId) public payable {
        require(isNFTForSale[_tokenId], "Token is not for sale");
        require(msg.value == salePrices[_tokenId], "Please submit the asking price in order to complete the purchase");
        
        address payable seller = payable(idToListedToken[_tokenId].owner);
        // transfer the token to the new owner - from, to, tokenId
        transferFrom(seller, msg.sender, _tokenId);

        // Transfer commission to the contract owner
        (bool commissionTransferSuccess, ) = payable(contractOwner).call{value: commissionFees}("");
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
        idToListedToken[_tokenId].price = salePrices[_tokenId];
        emit tokenHistory(_tokenId, msg.sender, salePrices[_tokenId]);
    }

    ////// View functions //////
    function getListedTokenForId(
        uint256 _tokenId
    ) public view returns (ListedToken memory) {
        return idToListedToken[_tokenId];
    }

    function getRoyaltyFees(uint256 _tokenId) public view returns (uint256) {
        require(_exists(_tokenId), "Token does not exist");
        return royaltyFees[_tokenId];
    }

    // Sale Activity and time left for the sale to end
    function saleActivity() public view returns (bool _saleActivity){
        if(block.timestamp > startTime && block.timestamp < startTime + duration){
            _saleActivity = true;
        } else {
            _saleActivity = false;
        }
        return _saleActivity;
    }
    function getStartTime() public view returns(uint256){
        require(startTime>0, "Sale has not been listed yet");
        return startTime;
    }
    function saleTimeLeft() public view returns (uint256 timeLeft) {
        require(startTime>0, "Sale has not been listed yet");
        timeLeft = startTime + duration - block.timestamp;
    }
    
    // This will return all the NFTs currently listed to be sold on the marketplace
    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint nftCount = _finalTokenId - 1; 
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
        uint totalItemCount = _finalTokenId - 1; 
        uint itemCount = 0;
        uint currentIndex = 0;
        uint currentId;
        // Get a count of all the NFTs that belong to the user
        for (uint i = 0; i < totalItemCount; i++) {
            if (
                idToListedToken[i + 1].owner == msg.sender ||
                idToListedToken[i + 1].lastOwner == msg.sender
            ) {
                itemCount += 1;
            }
        }

        // Storing all the relevant NFTs in an array
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