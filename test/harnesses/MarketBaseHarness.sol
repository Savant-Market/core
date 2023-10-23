// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {MarketBase} from "src/bases/MarketBase.sol";

contract MarketBaseHarness is MarketBase {
    function exposed___MarketBase_init(MarketSettings calldata _settings) external initializer {
        __MarketBase_init(_settings);
    }

    function workaround_setOutcome(uint128 _outcome) external {
        outcome = _outcome;
    }

    function exposed_resolve(uint128 _outcome) external {
        _resolve(_outcome);
    }

    function voteOnOutcome(uint128, uint256, address) external returns (uint256) {}
}