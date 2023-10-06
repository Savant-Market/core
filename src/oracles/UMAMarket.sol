// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "../pricing/AMMMarket.sol";
import "../interfaces/OptimisticOracleV3CallbackRecipientInterface.sol";
import "../interfaces/IMarketBase.sol";

contract UMAMarket is AMMMarket, OptimisticOracleV3CallbackRecipientInterface, IMarketBase {
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
    /// @param _feePPM The fee precentage that the markets charges for each vote. In parts per million (100% = 1_000_000)
    /// @param _metadata URI to the metadata (see docs for a schema file how the metadata needs to be structured)
    /// @param _duration Duration in seconds the market will be open
    /// @param _feeRecipient Recipient address that receives the market fees
    /// @param _possibleOutcomeCount Amount of possible outcomes defined in the metadata
    /// @param _creator Creator of the market

    function initialize(
        uint96 _startPrice,
        address[] memory _acceptedTokens,
        uint32 _feePPM,
        string memory _metadata,
        uint64 _startDate,
        uint32 _duration,
        address _feeRecipient,
        uint128 _possibleOutcomeCount,
        address _creator
    ) external initializer {
        __AMMMarket_init(
            _startPrice,
            _acceptedTokens,
            _feePPM,
            _metadata,
            _startDate,
            _duration,
            _feeRecipient,
            _possibleOutcomeCount,
            _creator
        );
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

    /// @inheritdoc IMarketBase
    function voteOnOutcome(address _token, uint256 _amount, uint128 _outcome) external {
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
    function supportsInterface(bytes4 _interfaceId) public pure virtual override(AMMMarket) returns (bool) {
        return UMAMARKET_INTERFACE_ID == _interfaceId || super.supportsInterface(_interfaceId);
    }
}
