// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {MarketBase} from "src/bases/MarketBase.sol";
import {IMarketBase} from "src/interfaces/IMarketBase.sol";
import {ERC1155Supply, ERC1155} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISignatureTransfer} from "permit2/src/interfaces/ISignatureTransfer.sol";

abstract contract DynamicBuyMarket is MarketBase, ERC1155Supply {
    using SafeERC20 for IERC20;

    /// @notice The [ERC-165](https://eips.ethereum.org/EIPS/eip-165) interface ID of the contract.
    bytes4 public constant DynamicBuyMarket_INTERFACE_ID =
        this.redeem.selector ^ this.calculatePrice.selector ^ this.isMarketResolved.selector;

    ISignatureTransfer public immutable PERMIT2;

    IERC20 public immutable DAI;

    uint96 public startPrice;
    uint256 public payoutPerShare;

    event DynamicBuyMarketInitialized(uint256 startPrice, string metadataURI);

    error NotWinningOutcome(uint128 winningOutcome, uint128 givenOutcome);
    error InvalidToken(address _given, address _expected);
    error InvalidPrice(uint96 _price);
    error AmountTooBig();

    constructor(ISignatureTransfer _permit2, IERC20 _dai) ERC1155("") {
        PERMIT2 = _permit2;
        DAI = _dai;
    }

    /// @notice Initialize function to initialize the storage of the minimal proxy contract
    /// @param _startPrice The initial price shares start trading
    /// @param _erc1155MetadataURI Metadata URI for the ERC1155 based shares. The metadata has to included 18 for the decimals property
    /// @param _settings Settings used to initialize the market
    function __DynamicBuyMarket_init(
        uint96 _startPrice,
        string memory _erc1155MetadataURI,
        MarketSettings calldata _settings
    ) internal onlyInitializing {
        __MarketBase_init(_settings);
        _setURI(_erc1155MetadataURI);
        startPrice = _startPrice;
        emit DynamicBuyMarketInitialized({startPrice: _startPrice, metadataURI: _erc1155MetadataURI});
    }

    function redeem(uint256 _amount, address _recipient) external onlyResolvedMarket {
        uint128 winningOutcome = outcome;
        _burn(msg.sender, winningOutcome, _amount);
        uint256 payout = payoutPerShare * _amount / RATIO_BASE;
        DAI.safeTransfer(_recipient, payout);
        emit Redeemed({recipient: _recipient, amountOfShares: _amount, payout: payout});
    }

    function calculatePrice(uint128 _outcome) public view returns(uint256) {
        return _calculatePrice(_outcome) / RATIO_BASE;
    }

    function _calculatePrice(uint128 _outcome) internal view onlyValidOutcome(_outcome) returns (uint256) {
        uint256 totalOutcomeSupply = totalSupply(_outcome);
        if (totalOutcomeSupply == 0) {
            return startPrice * RATIO_BASE;
        }

        return totalOutcomeSupply * startPrice * possibleOutcomeCount * RATIO_BASE / tvl;
    }

    /// @inheritdoc IMarketBase
    function voteOnOutcome(uint48 _outcome, uint232 _amount, address _recipient)
        external
        onlyValidOutcome(_outcome)
        returns (uint256)
    {
        // biggest possible amount
        if (_amount > type(uint232).max / RATIO_BASE) {
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
        if (_permit.permitted.amount > type(uint232).max / RATIO_BASE) {
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
        return _vote(_outcome, uint232(_permit.permitted.amount), _recipient);
    }

    function _vote(uint48 _outcome, uint232 _amount, address _recipient)
        private
        onlyValidOutcome(_outcome)
        onlyOpenMarket
        returns (uint256 shares)
    {
        uint256 fees = calculateFeeAmount(_amount);
        uint256 amountWithoutFees = _amount - fees;

        if (fees > 0) {
            collectedFees += fees;
        }
        tvl += amountWithoutFees;

        shares = amountWithoutFees * _calculatePrice(_outcome) / RATIO_BASE;
        _mint(_recipient, _outcome, shares, "");
        emit Voted({voter: msg.sender, recipient: _recipient, outcome: _outcome, shares: shares});
    }

    /// @notice Stores the payout per share and forwards the call in the inheritance chain
    /// @param _winningOutcome The outcome that has won
    function _resolve(uint48 _winningOutcome) internal virtual {
        uint256 totalSupplyOfOutcome = totalSupply(_winningOutcome);
        uint256 _payoutPerShare = 0;
        if (totalSupplyOfOutcome > 0) {
            _payoutPerShare = tvl * RATIO_BASE / totalSupplyOfOutcome;
            payoutPerShare = _payoutPerShare;
        }
        super._resolve(_winningOutcome, _payoutPerShare);
    }

    /// @notice Checks if this or the parent contract supports an interface by its ID.
    /// @param _interfaceId The ID of the interface.
    /// @return Returns `true` if the interface is supported.
    function supportsInterface(bytes4 _interfaceId) public view virtual override(MarketBase, ERC1155) returns (bool) {
        return DynamicBuyMarket_INTERFACE_ID == _interfaceId || MarketBase.supportsInterface(_interfaceId)
            || ERC1155.supportsInterface(_interfaceId);
    }
}
