// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "../../src/bases/MarketBase.sol";

contract MarketBaseNonAbstract is MarketBase {
    function initialize(
        uint32 _feePPM,
        string memory _metadata,
        uint64 _startDate,
        uint32 _duration,
        address _feeRecipient,
        uint128 _possibleOutcomeCount,
        address _creator
    ) external initializer {
        __MarketBase_init(_feePPM, _metadata, _startDate, _duration, _feeRecipient, _possibleOutcomeCount, _creator);
    }

    function setOutcome(uint128 _outcome) external {
        outcome = _outcome;
    }

    function resolve(uint128 _outcome) external {
        _resolve(_outcome);
    }

    function voteOnOutcome(address, uint256, uint128) external {}
}
