// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "../bases/MarketBase.sol";

abstract contract AMMMarket is MarketBase {
    uint96 public startPrice;
    address[] public acceptedTokens;

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
    ) public virtual initializer {
        MarketBase.initialize(_feePPM, _metadata, _startDate, _duration, _feeRecipient, _possibleOutcomeCount, _creator);
        startPrice = _startPrice;
        acceptedTokens = _acceptedTokens;
    }

    function redeem(uint256 _amount) external onlyResolvedMarket {
        // TODO create logic
    }

    function calculatePrice(address _token, uint256 _amount, uint128 _outcome)
        public
        onlyValidOutcome(_outcome)
        returns (uint256)
    {
        // TODO create logic
    }
}
