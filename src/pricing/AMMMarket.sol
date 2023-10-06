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
    /// @param _feePPM The fee precentage that the markets charges for each vote. In parts per million (100% = 1_000_000)
    /// @param _metadata URI to the metadata (see docs for a schema file how the metadata needs to be structured)
    /// @param _duration Duration in seconds the market will be open
    /// @param _feeRecipient Recipient address that receives the market fees
    /// @param _possibleOutcomeCount Amount of possible outcomes defined in the metadata
    /// @param _creator Creator of the market
    function __AMMMarket_init(
        uint96 _startPrice,
        address[] memory _acceptedTokens,
        uint32 _feePPM,
        string memory _metadata,
        uint64 _startDate,
        uint32 _duration,
        address _feeRecipient,
        uint128 _possibleOutcomeCount,
        address _creator
    ) internal onlyInitializing {
        __MarketBase_init(_feePPM, _metadata, _startDate, _duration, _feeRecipient, _possibleOutcomeCount, _creator);
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
