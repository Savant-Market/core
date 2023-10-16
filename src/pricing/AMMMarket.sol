// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {MarketBase} from "src/bases/MarketBase.sol";
import {IMarketBase} from "src/interfaces/IMarketBase.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

abstract contract AMMMarket is MarketBase, ERC1155 {
    /// @notice The [ERC-165](https://eips.ethereum.org/EIPS/eip-165) interface ID of the contract.
    bytes4 public constant AMMMARKET_INTERFACE_ID =
        this.redeem.selector ^ this.calculatePrice.selector ^ this.isMarketResolved.selector;

    uint96 public startPrice;
    address[] public acceptedTokens;

    constructor() ERC1155("") {}

    /// @notice Initialize function to initialize the storage of the minimal proxy contract
    /// @param _startPrice The initial price shares start trading
    /// @param _acceptedTokens Tokens that are accepted by the market as payment
    /// @param _settings Settings used to initialize the market
    function __AMMMarket_init(uint96 _startPrice, address[] memory _acceptedTokens, MarketSettings calldata _settings)
        internal
        onlyInitializing
    {
        __MarketBase_init(_settings);
        startPrice = _startPrice;
        acceptedTokens = _acceptedTokens;
    }

    function redeem(uint256 _amount) external onlyResolvedMarket {
        // TODO create logic
    }

    function calculatePrice(address, uint256 _amount, uint128 _outcome)
        public
        view
        onlyValidOutcome(_outcome)
        returns (uint256)
    {}

    /// @inheritdoc IMarketBase
    function voteOnOutcome(uint128 _outcome, uint256 _amount, address _recipient) external returns (uint256) {
        // TODO create logic
    }

    /// @notice Checks if this or the parent contract supports an interface by its ID.
    /// @param _interfaceId The ID of the interface.
    /// @return Returns `true` if the interface is supported.
    function supportsInterface(bytes4 _interfaceId) public view virtual override(MarketBase, ERC1155) returns (bool) {
        return AMMMARKET_INTERFACE_ID == _interfaceId || MarketBase.supportsInterface(_interfaceId)
            || ERC1155.supportsInterface(_interfaceId);
    }
}
