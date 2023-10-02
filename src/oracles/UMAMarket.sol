// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "../pricing/AMMMarket.sol";
import "../interfaces/OptimisticOracleV3CallbackRecipientInterface.sol";
import "../interfaces/IMarketBase.sol";

contract UMAMarket is AMMMarket, OptimisticOracleV3CallbackRecipientInterface, IMarketBase {
    address public immutable ORACLE;
    uint64 public immutable DISPUTE_WINDOW;
    uint256 public assertedOutcome;
    bytes32 public assertionId;
    bool public disputed;

    modifier onlyOracle() {
        // TODO create logic
    }
    modifier onlyDisputed() {
        // TODO create logic
    }

    constructor(address _oracle, uint64 _disputeWindow) {
        ORACLE = _oracle;
        DISPUTE_WINDOW = _disputeWindow;
    }

    function assertMarket() external onlyClosedMarket {
        // TODO create logic
    }
    function assertMarket(uint128 _outcome) external onlyDisputed onlyValidOutcome(_outcome) onlyClosedMarket {
        // TODO create logic
    }
    function getDisputeWindow() internal returns (uint256) {
        // TODO create logic
    }

    /// @inheritdoc OptimisticOracleV3CallbackRecipientInterface
    function assertionResolvedCallback(bytes32 assertionId, bool assertedTruthfully) external {
        // TODO create logic
    }

    /// @inheritdoc OptimisticOracleV3CallbackRecipientInterface
    function assertionDisputedCallback(bytes32 assertionId) external {
        // TODO create logic
    }

    /// @inheritdoc IMarketBase
    function voteOnOutcome(address _token, uint256 _amount, uint128 _outcome) external {
        // TODO create logic
    }
}
