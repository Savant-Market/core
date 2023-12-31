// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

interface IMarketBase {
    error MarketNotOpen();
    error MarketNotClosed(uint64 endDate, uint64 timestamp);
    error MarketNotResolved();
    error InvalidOutcome(uint128 givenOutcome, uint128 possibleOutcomeCount);

    event MarketResolved(uint128 outcome, uint256 payoutPerShare);
    event MarketBaseInitialized(MarketSettings settings);
    event Voted(address indexed voter, address indexed recipient, uint256 outcome, uint256 shares);
    event Redeemed(address indexed recipient, uint256 amountOfShares, uint256 payout);

    struct MarketSettings {
        uint32 feePPM;
        string metadata;
        uint64 startDate;
        uint32 duration;
        address feeRecipient;
        uint48 possibleOutcomeCount;
        address creator;
    }

    /// @notice Vote on a certain outcome and receive the shares
    /// @param _outcome Which outcome the user votes for
    /// @param _amount Amount of tokens the user spends
    /// @param _recipient Recipient of the shares. Has to be an ERC1155Receiver if it is a contract
    /// @return Amount of shares minted for the given outcome
    function voteOnOutcome(uint48 _outcome, uint232 _amount, address _recipient) external returns (uint256);

    /// @notice Calculates the fee for the inputed amount
    /// @param _amount Amount that the fee should be calculated for
    /// @return The fee that would be deducted
    function calculateFeeAmount(uint232 _amount) external view returns (uint256);

    /// @notice Check if the market is open and ready for predictions
    /// @return Returns `true` if the market is open
    function isMarketOpen() external view returns (bool);

    /// @notice Check if the market is resolved
    /// @return Returns `true` if the market is resolved
    function isMarketResolved() external view returns (bool);

    /// @notice Returns false if the market end date is bigger than the current time
    /// @return Returns `true` if the market is closed
    function isMarketClosed() external view returns (bool);
}
