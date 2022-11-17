// SPDX-License-Identifier: UNLICENSED
/*
*
* EMTRI Corporation, incorporated and registered in California, USA; 'EMTRI'.
*
* EMTRI empowers the Farmers, Cultivators, Strain Producers and Distributors 
* (clients) who work to bring quality medical-grade & premium adult-use cannabis 
* to the market.
*
* EMTRI clients use Ethereum blockchain technologies to attest to their crop 
* cultivations. In return for attesting to crop lifecycle events using blockchain, 
* EMTRI rewards its clients with EMT tokens, the 'mint'.
*
* EMTRI introduces clients to cannabis distributors that sell the attested-to
* cannabis to wholesale and retail customers, who actually pay a cash premium to 
* EMTRI because the cannabis their clients produce is attestested to using blockchain.
*
* Up to 50% of the cash premium paid to EMTRI is used to buyback EMT tokens on the
* Uniswap decentralized token exchange, the 'burn'. 

* So, EMTs are minted only as cultivator and distributor rewards, and then bought
* back upon the sale of the client cannabis, thereby creating the Uniswap marketplace.
*
*
* https://abbey.ch/         -- Abbey Technology GmbH, Zug, Switzerland
* 
* ABBEY DEFI
* ========== 
* 1. Decentralized Finance (DeFi) is designed to be globally inclusive. 
* 2. Centralized finance is based around private share sales to wealthy individuals or
*    the trading of shares on national stock markets, both have high barriers to entry. 
* 3. The Abbey DeFi methodology offers public and private companies exposure to DeFi.
*
* Abbey is a Uniswap-based DeFi service provider that allows companies to offer people a 
* novel way to participate in the success a business may have in a decentralized manner.
* 
* The premise is both elegant and simple, the company commits to a token buyback based on 
* its revenues.
* 
* Using Abbey as a Uniswap DeFi management agency, the company spends some revenues 
* buying one side of a bespoke Uniswap trading pair. The other side of the Uniswap pair 
* is the EMT token.
* 
* DeFi traders wishing to participate in the success a business may have deposit USDC in return 
* for EMT tokens. The Uniswap Automated Market Maker ensures DeFi market liquidity and
* legitimate price discovery. The more USDC that the company deposits in buy backs over time, 
* the higher the value of the EMT token, as held by DeFi speculators.
*
*/

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title EMT Token contract for Uniswap v3.
 * @author Abbey Technology GmbH
 * @notice Token contract for use with Uniswap. Enforces restrictions outlined on the website.
 */
contract EMTToken is ERC20 {

    /**
     * @notice The details of a future company cashout.
     */
    struct Notice {
        // The maximum number of tokens proposed for sale.
        uint256 amount;

        // The date after which company tokens can be swapped.
        uint256 releaseDate;
    }

    // Event fired when a restricted wallet gives notice of a potential future trade.
    event NoticeGiven(address indexed who, uint256 amount, uint256 releaseDate);

    /**
     * @notice Notice must be given to the public before treasury tokens can be swapped.
     */
    Notice public noticeTreasury;

    /**
     * @notice Notice must be given to the public before Liquidity Tokens can be removed from the pool.
     */
    Notice public noticeLiquidity;

    /**
    * @notice The account that created this contract, also functions as the liquidity provider.
    */
    address public owner;

    /**
     * @notice Holder of the company's tokens.  Must give notice before tokens are moved.
     */
    address public treasury;

    /**
     * @notice The account that performs the buyback of tokens, all bought tokens are burned.
     * @dev They cannot be autoburned during transfer as the Uniswap client prevents the transaction.
     */
    address public buyback;

    /**
     * @notice The account that facilitates moving tokens between Mainnet and Efixii L2.
     */
    address public flip;    

    /**
     * @notice The address of the Uniswap Pool ERC20 contract holding the Liquidity Pool tokens.
     */
    address public poolAddress;

    /**
     * @notice The address of the Uniswap NFT ERC721 Positions contract that tracks ownership of liquidity pools.
     */
    address public positionsAddress;

    /**
     * @notice The NFT id of the Liquidity Pool in the Uniswap Positions contract.
     */
    uint256 public nftId;    

    /**
     * @notice The minimum duration notice given (to give the public a chance to act and to prevent a rug pull).
     */
    uint256 private MinimumNotice = 7 days;

    /**
     * @notice Restrict functionaly to the contract owner.
     */
    modifier onlyOwner {
        require(_msgSender() == owner, "You are not Owner.");
        _;
    }

    /**
     * @notice Create the contract setting already known values that are unlikely to change.  The tokens for the Uniswap
     *         liquidity pool are also created.
     * 
     * @param initialSupply The number of tokens to create the Uniswap pool.
     * @param name          The name of the token.
     * @param symbol        The short symbol for this token.
     * @param treasuryAddr  The address of the treasury wallet.
     * @param buybackAddr   The wallet that performs buybacks and optional burns of tokens.
     * @param flipAddr      The wallet used to move tokens between L2 and Mainnet.
     */
    constructor(uint256 initialSupply, string memory name, string memory symbol, address treasuryAddr, address buybackAddr, address flipAddr, address positionsAddr) ERC20(name, symbol) {
        owner = _msgSender();

        treasury = treasuryAddr;
        buyback = buybackAddr;
        flip = flipAddr;
        positionsAddress = positionsAddr;

        _mint(owner, initialSupply);
    }

    /**
     * @notice Set the address of the account holding EMT tokens on behalf of the company.
     */
    function setTreasury(address who) public onlyOwner {
        require(who != address(0x0), "Cannot assign to null address");

        _migrateTokens(treasury, who);
        treasury = who;
    }

    /**
     * @notice Set the address of the company account that buys tokens to increase the token price.
     */
    function setBuyback(address who) public onlyOwner {
        require(who != address(0x0), "Cannot assign to null address");

        _migrateTokens(buyback, who);
        buyback = who;
    }

    /**
     * @notice Set the address of the account that allows moving tokens between L2 and Mainnet.
     */
    function setFlip(address who) public onlyOwner {
        require(who != address(0x0), "Cannot assign to null address");

        _migrateTokens(flip, who);
        flip = who;
    }

    /**
     * When changing the address of a role in the contract move all tokens to the new
     * address - the tokens are restricted by role so need to move with the role address
     * change.
     */
    function _migrateTokens(address from, address to) private {
        if(from != address(0x0) && balanceOf(from) > 0)
            _transfer(from, to, balanceOf(from));
    }

    /**
     * @notice Set the address of the Uniswap Pool contract.
     */
    function setPoolAddress(address who) public onlyOwner {
        poolAddress = who;
    }

    /**
     * @notice Set the address of the Uniswap NFT contract that tracks Liquidity Pool ownership.
     */
    function setPositionsAddress(address who) public onlyOwner {
        positionsAddress = who;
    }

    /**
     * @notice Set the id of the position token that determines ownership of the Liquidity Pool.
     */
    function setNftId(uint256 id) public onlyOwner {
        nftId = id;
    }

    /**
     * @notice Treasury tokens must give advanced notice to the public before they can be used.
     * A public announcement will be made at the same time this notice is set in the contract.
     *
     * @param who The treasury address.
     * @param amount The maximum number of tokens (in wei).
     * @param numSeconds The number of seconds the tokens are held before being acted on.
     */
    function treasuryTransferNotice(address who, uint256 amount, uint256 numSeconds) public onlyOwner {
        require(who == treasury, "Specified address is not Treasury.");
        require(numSeconds >= MinimumNotice, "Not enough notice given.");

        uint256 when = block.timestamp + (numSeconds * 1 seconds);

        require(noticeTreasury.releaseDate == 0 || block.timestamp >= noticeTreasury.releaseDate, "Cannot overwrite an active existing notice.");
        require(amount <= balanceOf(who), "Can't give notice for more EMT tokens than owned.");
        noticeTreasury = Notice(amount, when);
        emit NoticeGiven(who, amount, when);
    }

    /**
     * @notice Liquidity Pool tokens must give advanced notice to the public before they can be used.
     * A public announcement will be made at the same time this notice is set in the contract.     
     *
     * @param who The owner of the Uniswap Positions NFT token.
     * @param amount The maximum number of tokens (in wei).
     * @param numSeconds The number of seconds the tokens are held before being acted on.
     */
    function liquidityRedemptionNotice(address who, uint256 amount, uint256 numSeconds) public onlyOwner {
        require(positionsAddress != address(0), "Uniswap Position Manager must be set.");
        require(numSeconds >= MinimumNotice, "Not enough notice given.");
        require(nftId != 0, "Uniswap Position NFT Id must be set.");
        require(poolAddress != address(0), "The Uniswap Pool contract address must be set.");

        IERC721 positions = IERC721(positionsAddress);
        address lpOwner = positions.ownerOf(nftId);
        require(who == lpOwner, "The specified address does not own the Positions NFT Token.");

        uint256 when = block.timestamp + (numSeconds * 1 seconds);

        require(noticeLiquidity.releaseDate == 0 || block.timestamp >= noticeLiquidity.releaseDate, "Cannot overwrite an active existing notice.");
        require(amount <= balanceOf(poolAddress), "Can't give notice for more Liquidity Tokens than owned.");
        noticeLiquidity = Notice(amount, when);
        emit NoticeGiven(who, amount, when);
    }

    /**
     * @notice Enforce rules around the company accounts:
     * - Once buyback buys tokens they can never be moved, the only real option is to burn.
     * - Two key accounts: treasury and the owner of the liquidity pool are restricted.
     * - A public announcement of the company's intent along with a time locked notice set in this contract before any token movement.
     * - Only after the deadline can these restricted tokens move.
     * - No restrictions are in place for any other wallet.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(sender != buyback, "Buyback cannot transfer tokens, it can only burn.");
        if(sender == treasury) {
            require(noticeTreasury.releaseDate != 0 && block.timestamp >= noticeTreasury.releaseDate, "Notice period has not been set or has not expired.");
            require(amount <= noticeTreasury.amount, "Treasury can't transfer more tokens than given notice for.");

            // Clear the remaining notice balance, this prevents giving notice on all tokens and
            // trickling them out.
            noticeTreasury = Notice(0, 0);
        }
        else if(nftId != 0) { // Check if the receiver is the Liquidity Pool owner.
            IERC721 positions = IERC721(positionsAddress);
            address lpOwner = positions.ownerOf(nftId);
            if(recipient == lpOwner) {
                require(noticeLiquidity.releaseDate != 0 && block.timestamp >= noticeLiquidity.releaseDate, "LP notice period has not been set or has not expired.");
                require(amount <= noticeLiquidity.amount, "LP can't transfer more tokens than given notice for.");

                // Clear the remaining notice balance, this prevents giving notice on all tokens and
                // trickling them out.
                noticeLiquidity = Notice(0, 0);
            }
        }

        super._transfer(sender, recipient, amount);
    }

    /**
     * @notice mint is only called when EMT tokens are burned on the L2 side of the EMT bridge 
     * and are then minted one-for-one to this contract on the Mainnet L1 side of the EMT bridge.
     * Once minted, EMTs are ready to trade on Uniswap.
     *
     * @param who The address to mint to the tokens to.
     * @param quantity The number of tokens to create, in wei.
     */
    function mint(address who, uint256 quantity) public onlyOwner {
        _mint(who, quantity);
    }

    /**
     * @notice Tokens are burned here on Mainnet to reduce total supply available to trade on Uniswap.
     *
     * @param quantity The number of tokens to destroy, in wei.
     */
    function burn(uint256 quantity) public {
        _burn(_msgSender(), quantity);
    }
}
