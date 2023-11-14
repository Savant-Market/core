// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {MarketBase} from "src/bases/MarketBase.sol";
import {IMarketBase} from "src/interfaces/IMarketBase.sol";
import {ERC1155, ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISignatureTransfer} from "permit2/src/interfaces/ISignatureTransfer.sol";

abstract contract FixedPriceMarket is MarketBase, ERC1155Supply {
    using SafeERC20 for IERC20;

    /// @notice The [ERC-165](https://eips.ethereum.org/EIPS/eip-165) interface ID of the contract.
    bytes4 public constant FIXED_PRICE_MARKET_INTERFACE_ID =
        this.voteOnOutcome.selector ^ this.permitVoteOnOutcome.selector ^ this.redeem.selector;

    /// @dev inflate the amount of shares by 18 0s
    uint64 public constant SHARES_MODIFIER = 1e18;

    IERC20 public immutable DAI;
    ISignatureTransfer public immutable PERMIT2;
    uint256 public price;
    uint256 public payoutPerShare;

    error NotEnoughShares(uint256 _requested, uint256 _actual);
    error InvalidToken(address _given, address _expected);
    error InvalidPrice(uint96 _price);
    error AmountTooBig();

    event FixedPriceMarketInitialized(uint256 price, string metadataURI);
    event SharesRedeemed(
        address indexed holder, address indexed recipient, uint256 amountOfShares, uint256 payoutAmount
    );

    constructor(IERC20 _dai, ISignatureTransfer _permit2) ERC1155("") {
        DAI = _dai;
        PERMIT2 = _permit2;
    }

    /// @notice Initialize function to initialize the storage of the minimal proxy contract
    /// @param _price The price for which a user receives 1 share
    /// @param _erc1155MetadataURI Metadata URI for the ERC1155 based shares. The metadata has to included 18 for the decimals property
    /// @param _settings Settings used to initialize the market
    function __FixedPriceMarket_init(
        uint96 _price,
        string memory _erc1155MetadataURI,
        MarketSettings calldata _settings
    ) internal onlyInitializing {
        // price cannot be 0
        if (_price < 1) {
            revert InvalidPrice({_price: _price});
        }

        __MarketBase_init(_settings);
        _setURI(_erc1155MetadataURI);
        price = _price;
        emit FixedPriceMarketInitialized({price: _price, metadataURI: _erc1155MetadataURI});
    }

    /// @inheritdoc IMarketBase
    function voteOnOutcome(uint48 _outcome, uint232 _amount, address _recipient) external override returns (uint256) {
        // biggest possible amount
        if (_amount > type(uint232).max / SHARES_MODIFIER) {
            revert AmountTooBig();
        }

        DAI.safeTransferFrom(msg.sender, address(this), _amount);
        return _vote(_outcome, _amount, _recipient);
    }

    /// @notice Votes with the amount given for the outcome defined. Tokens gets send to the recipient
    /// @dev Follows the Permit2 flow. For the classic allow/transfer flow use `voteOnOutcome()`
    /// @param _permit Struct to define the settings forwareded to the permit2 contract
    /// @param _signature Signature forwarded to permit2
    /// @param _outcome Which outcome the user votes for
    /// @param _recipient Recipient of the shares. Has to be an ERC1155Receiver if it is a contract
    /// @return Amount of shares minted for the given outcome
    function permitVoteOnOutcome(
        ISignatureTransfer.PermitTransferFrom calldata _permit,
        bytes calldata _signature,
        uint48 _outcome,
        address _recipient
    ) external returns (uint256) {
        // biggest possible amount
        if (_permit.permitted.amount > type(uint232).max / SHARES_MODIFIER) {
            revert AmountTooBig();
        }
        if (_permit.permitted.token != address(DAI)) {
            revert InvalidToken(_permit.permitted.token, address(DAI));
        }
        PERMIT2.permitTransferFrom(
            _permit,
            ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: _permit.permitted.amount}),
            msg.sender,
            _signature
        );
        return _vote(_outcome, uint200(_permit.permitted.amount), _recipient);
    }

    /// @notice Reedm shares for tokens if the defined amount is hold for the winning outcome
    /// @param _amount Amount of shares a user wants to redeem
    /// @param _recipient Which address should receive the payout
    /// @return payout The amount of tokens that got paied out
    function redeem(uint256 _amount, address _recipient) public onlyResolvedMarket returns (uint256 payout) {
        uint48 winningOutcome = outcome;
        uint256 userBalance = balanceOf(msg.sender, winningOutcome);
        if (_amount > userBalance + 1) {
            revert NotEnoughShares(_amount, userBalance);
        }
        payout = payoutPerShare * _amount;
        _burn(msg.sender, winningOutcome, _amount);
        DAI.transfer(_recipient, payout);
        emit SharesRedeemed({holder: msg.sender, recipient: _recipient, amountOfShares: _amount, payoutAmount: payout});
    }

    /// @notice Burn shares if wanted. Redeems if the defined outcome is the winning outcome
    /// @param _outcome Outcome from which the shares should be burned
    /// @param _amount Amount of shares to burn
    function burn(uint48 _outcome, uint256 _amount) external {
        if (_outcome == outcome) {
            redeem(_amount, msg.sender);
            return;
        }
        _burn(msg.sender, _outcome, _amount);
    }

    /// @notice Checks if this or the parent contract supports an interface by its ID.
    /// @param _interfaceId The ID of the interface.
    /// @return Returns `true` if the interface is supported.
    function supportsInterface(bytes4 _interfaceId) public view virtual override(MarketBase, ERC1155) returns (bool) {
        return FIXED_PRICE_MARKET_INTERFACE_ID == _interfaceId || MarketBase.supportsInterface(_interfaceId)
            || ERC1155.supportsInterface(_interfaceId);
    }

    /// @notice Deducts the fees and mints the shares for the given outcome and amount
    /// @param _outcome Outcome to vote for
    /// @param _amount Amount of tokens to vote with
    /// @param _recipient Recipient of the shares. Has to be an ERC1155Receiver if it is a contract
    /// @return shares Amount of shares minted
    function _vote(uint48 _outcome, uint232 _amount, address _recipient)
        internal
        onlyValidOutcome(_outcome)
        onlyOpenMarket
        returns (uint256 shares)
    {
        uint256 fees = calculateFeeAmount(_amount);
        shares = uint256(_amount - fees) * price / SHARES_MODIFIER;
        tvl += _amount - fees;
        // only store fees if necessary
        if (fees > 0) {
            collectedFees += fees;
        }
        _mint(_recipient, _outcome, shares, "Savant");
        emit Voted({voter: msg.sender, recipient: _recipient, outcome: _outcome, shares: shares});
    }

    /// @notice Stores the payout per share and forwards the call in the inheritance chain
    /// @param _winningOutcome The outcome that has won
    function _resolve(uint48 _winningOutcome) internal virtual override {
        uint256 totalSupplyOfOutcome = totalSupply(_winningOutcome);
        if (totalSupplyOfOutcome > 0) {
            payoutPerShare = tvl / totalSupplyOfOutcome;
        }
        super._resolve(_winningOutcome);
    }
}
