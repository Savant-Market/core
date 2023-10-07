// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "../../src/bases/MarketBase.sol";

contract MarketBaseNonAbstract is MarketBase {
    function initialize(MarketSettings calldata _settings) external initializer {
        __MarketBase_init(_settings);
    }

    function setOutcome(uint128 _outcome) external {
        outcome = _outcome;
    }

    function resolve(uint128 _outcome) external {
        _resolve(_outcome);
    }

    function voteOnOutcome(address, uint256, uint128) external {}
}
