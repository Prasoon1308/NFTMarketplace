# NFTMarketplace contract

## Deployed contract on the shibarium mainnet
Shibuki.io
https://www.shibariumscan.io/address/0x63993221Bc120d6E6fe794d8B37C307F20D45a04

Fuzuki.io
https://www.shibariumscan.io/address/0x3ba4792Ce252488D71513B86c80643538056E7A4


## Contract Flow

On deploying the contract, the address of the deployer will be saved in Owner. The commission fees and a normal presale duration will be set at the deployment of the contract. The contract owner can give access to an address for minting new NFTs using `setArtist` function. By default the contract owner will also get the moderator access.

To access some of the set/change functions of the contract, access can be given to moderator using the `setModerator` function. By default the contract owner will also get the moderator access. This function is used to implement the idea of multisig wallet usage for some of the functions later. 

The address with artist access can use the `mintNFT` function to mint new NFTs ( bunch or single)

The moderators can also reset the time of start of the presale and the duration of presale using the `updatePresaleTime` function. Also the discount for the presale can be set using setPresaleDiscount function by the moderator only.

The buyer can use the `presale` function to buy the newly minted NFTs. The buyer has to send the amount of presalePrice (which is discounted price, can be retrieved by knowing presaleDiscount) to buy the NFT.

To resell an NFT, the owner has to list the NFT open for sale using the function `listNFTForSale` with new salePrice. Freshly minted NFTs are already all for sale if they are not sold in presale. 

The interested buyers can buy the NFT using the `sale` function. The buyer can view the amount that has to be sent by viewing the `salePrices` mapping for that tokenId.


## Functions in detail

# Write Functions
setModerator(address _moderator) -  to set a new moderator address. 
Moderator has access to functions : changeCommissionFees, setArtist, setBaseURI, updatePresaleTime
(Only the contract owner can use this function)
setArtist(address _artist) -  to set a new artist address.
Artist has access to functions : setTokenPricebyCategory, mint
(Only moderator address can use this function)
setBaseURI(string calldata baseURI) - to set the base URI for tokens.
(Only moderator address can use this function)
changeCommissionFees(uint256 newCommissionFees) - to change the commission fees.
(Only moderator address can use this function)
setTokenPricebyCategory(Category category, uint256 categoryPrice) - to set the price per token category. Takes enum value (0 for premium, 1 for normal) and the respective price
	(Only artist address can use this function)
mint(uint256 quantity, uint256 fees, Category batchCategory, string[] memory _tokenURIs) - to mint new tokens. Takes quantity, royalty fees, enum value(for category) and the respective tokenURI values
(Only artist address can use this function and the length of array should match the quantity specified)
setPresaleDiscount(uint256 _presaleDiscount) - to set the presale discount percentage.
(Only the contract owner can use this function)
updatePresaleTime(uint256 _startTime, uint256 _duration) - to update the presale start time and duration.
(Only moderator address can use this function)
presale(uint256 tokenId) - to participate in the presale of a token by buying it at a discounted price. The buyer needs to  send the presale price which is the category token price - discount.
(Can only be used during the presale period, and only the freshly minted token must be available for sale)
sale(uint256 tokenId) -  to purchase tokens listed for sale. The freshly minted tokens which were not sold in the presale are available for direct sale here and an owner can resell their tokens using this. The buyer needs to send the listed price (category price for the freshly minted tokens)
(Only the tokens with listed for sale can be bought)


# Read Functions

moderator (address) - mapping, returns if the address has access to onlyModerator functions or not
canMint(address) - mapping, returns if the address has access to onlyArtist functions or not
originalCreators(uint256) - mapping, returns the address of the NFT creator for that tokenId
commissionFees - uint, returns the commission fees for the platform
duration - uint, returns the set duration for the presale
ownerOf(uint256 tokenId) - returns the current owner of the token
balanceOf(address owner) - returns number of NFTs an address has
tokenURI(uint256 _tokenId) - returns the URI for a specific token, which can be used to access metadata about the token.
getListedTokenForId(uint256 tokenId) - returns details about a listed token (like owner, last owner, price, royalty fees, category, sale status) by its tokenId.
getRoyaltyFees(uint256 tokenId) - returns the royalty fees for a specific token.
pricePerTokenCategory(uint8) - mapping, returns the price per category; takes enum value as input
saleActivity() - checks if a sale is active and calculates the time left for the current sale period.
startTime - uint, retrieves the presale start time
totalSupply - uint, retrieves the last tokenId minted value
presaleDiscount() - uint, retrieves the discount percentage applicable in the presale
getMyNFTs() - retrieves a list of NFTs owned by the caller and its details.


## ERC721A standards

`function _mint(address to, uint256 quantity)` - minting new quantity number of  NFTS to an address 
`internalTransfer(address from, address to, uint256 tokenId)` - function to have handle transfers of presale and sale functions from the NFT contract which doesn’t require approval process
`function transferFrom(address from, address to, uint256 tokenId)` - Transfers _tokenId_ from _from_ to _to_ 
`function tokenURI(uint256 tokenId)` - returns the full URI of a specific token by combining the _baseUri_ and the _tokenId_
`function _baseURI()` - to update the base uri for the NFT
`function approve(address to, uint256 tokenId)` - to approve the address _to_ to transfer _tokenId_ to another account
`function _exists(uint256 tokenId)` - to check whether the token of _tokenId_ exists
`function setApprovalForAll(address operator, bool approved)` - Approve or remove _operator_ as an operator for for any token owned by the caller