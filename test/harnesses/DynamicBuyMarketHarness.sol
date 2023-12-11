// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {DynamicBuyMarket} from "src/pricing/DynamicBuyMarket.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ISignatureTransfer} from "permit2/src/interfaces/ISignatureTransfer.sol";

contract DynamicBuyMarketHarness is DynamicBuyMarket {
    constructor(ISignatureTransfer permit2, IERC20 dai) DynamicBuyMarket(permit2, dai) {}

    function exposed___DynamicBuyMarket_init(
        uint96 _startPrice,
        string memory _erc1155MetadataURI,
        MarketSettings calldata _settings
    ) external initializer {
        __DynamicBuyMarket_init(_startPrice, _erc1155MetadataURI, _settings);
    }

    function exposed__resolve(uint48 _outcome) public {
        _resolve(_outcome);
    }
}
