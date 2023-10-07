// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "../bases/MarketBase.sol";

abstract contract AMMMarket is MarketBase {
    /// @notice The [ERC-165](https://eips.ethereum.org/EIPS/eip-165) interface ID of the contract.
    bytes4 public constant AMMMARKET_INTERFACE_ID =
        this.redeem.selector ^ this.calculatePrice.selector ^ this.isMarketResolved.selector;

    uint96 public startPrice;
    address[] public acceptedTokens;

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

    function calculatePrice(address _token, uint256 _amount, uint128 _outcome)
        public
        onlyValidOutcome(_outcome)
        returns (uint256)
    {
        // TODO create logic
    }

    /// @notice Checks if this or the parent contract supports an interface by its ID.
    /// @param _interfaceId The ID of the interface.
    /// @return Returns `true` if the interface is supported.
    function supportsInterface(bytes4 _interfaceId) public view virtual override(MarketBase) returns (bool) {
        return AMMMARKET_INTERFACE_ID == _interfaceId || super.supportsInterface(_interfaceId);
    }
}
