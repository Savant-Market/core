// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {AMMMarket} from "src/pricing/AMMMarket.sol";
import {IMarketBase} from "src/interfaces/IMarketBase.sol";
import {OptimisticOracleV3CallbackRecipientInterface} from
    "src/interfaces/OptimisticOracleV3CallbackRecipientInterface.sol";

contract UMAMarket is AMMMarket, OptimisticOracleV3CallbackRecipientInterface {
    /// @notice The [ERC-165](https://eips.ethereum.org/EIPS/eip-165) interface ID of the contract.
    bytes4 public constant UMAMARKET_INTERFACE_ID = this.initialize.selector ^ this.disputeMarket.selector
        ^ this.assertionResolvedCallback.selector ^ this.assertionDisputedCallback.selector ^ this.voteOnOutcome.selector
        ^ this.getDisputeWindow.selector;

    address public immutable ORACLE;
    uint64 public immutable DISPUTE_WINDOW;
    uint256 public assertedOutcome;
    bytes32 public assertionId;
    bool public disputed;

    error Unauthorized(address caller, address expected);
    error NotInDisputeWindow(uint256 disputeWindowEnd, uint256 currentTime);

    /// @notice Reverts if the caller is not the oracle
    modifier onlyOracle() {
        if (msg.sender != ORACLE) {
            revert Unauthorized({caller: msg.sender, expected: ORACLE});
        }
        _;
    }

    /// @notice Reverts if the market is not in the dispute window
    modifier onlyInDisputeWindow() {
        if (isInDisputeWindow()) {
            revert NotInDisputeWindow({disputeWindowEnd: getDisputeWindow(), currentTime: block.timestamp});
        }
        _;
    }

    constructor(address _oracle, uint64 _disputeWindow) {
        ORACLE = _oracle;
        DISPUTE_WINDOW = _disputeWindow;
    }

    /// @notice Initialize function to initialize the contract and its dependencies
    /// @param _startPrice The initial price shares start trading
    /// @param _acceptedTokens Tokens that are accepted by the market as payment
    /// @param _settings Settings used to initialize the market

    function initialize(uint96 _startPrice, address[] memory _acceptedTokens, MarketSettings calldata _settings)
        external
        initializer
    {
        __AMMMarket_init(_startPrice, _acceptedTokens, _settings);
    }

    /// @notice Function to dispute the market if you don't agree with the outcome. By default the market assumes that the most popular outcome it the truth
    /// @dev Dispute can happen while the market is in the dispute window
    function disputeMarket(uint128 _outcome) external onlyValidOutcome(_outcome) onlyInDisputeWindow {
        // TODO create logic
    }

    /// @inheritdoc OptimisticOracleV3CallbackRecipientInterface
    function assertionResolvedCallback(bytes32 _assertionId, bool _assertedTruthfully) external {
        // TODO create logic
    }

    /// @inheritdoc OptimisticOracleV3CallbackRecipientInterface
    function assertionDisputedCallback(bytes32 _assertionId) external {
        // TODO create logic
    }

    function getDisputeWindow() public view returns (uint256) {
        return endDate + DISPUTE_WINDOW;
    }

    function isInDisputeWindow() public view returns (bool) {
        return getDisputeWindow() < block.timestamp;
    }

    /// @notice Checks if this or the parent contract supports an interface by its ID.
    /// @param _interfaceId The ID of the interface.
    /// @return Returns `true` if the interface is supported.
    function supportsInterface(bytes4 _interfaceId) public view virtual override(AMMMarket) returns (bool) {
        return UMAMARKET_INTERFACE_ID == _interfaceId || super.supportsInterface(_interfaceId);
    }
}
