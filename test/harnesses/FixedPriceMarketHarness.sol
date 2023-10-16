// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "src/pricing/FixedPriceMarket.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FixedPriceMarketHarness is FixedPriceMarket {
    constructor(IERC20 _dai, IAllowanceTransfer _permit2) FixedPriceMarket(_dai, _permit2) {}

    function exposed___FixedPriceMarket_init(uint96 _price, string memory _metadata, MarketSettings calldata _settings)
        external
        initializer
    {
        __FixedPriceMarket_init(_price, _metadata, _settings);
    }

    function exposed_resolve(uint128 _outcome) external {
        _resolve(_outcome);
    }
}
