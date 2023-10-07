// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

interface IMarketBase {
    error MarketNotOpen();
    error MarketNotClosed(uint64 endDate, uint64 timestamp);
    error MarketNotResolved();
    error NotValidOutcome(uint128 givenOutcome, uint128 possibleOutcomeCount);

    event MarketResolved(uint128 outcome);

    struct MarketSettings {
        uint32 feePPM;
        string metadata;
        uint64 startDate;
        uint32 duration;
        address feeRecipient;
        uint128 possibleOutcomeCount;
        address creator;
    }

    /// @notice Vote on a certain outcome and receive the shares
    /// @param _token In which token the user pays
    /// @param _amount Amount of tokens the user spends
    /// @param _outcome Which outcome the user votes for
    function voteOnOutcome(address _token, uint256 _amount, uint128 _outcome) external;

    /// @notice Calculates the fee for the inputed amount
    /// @param _amount Amount that the fee should be calculated for
    /// @return The fee that would be deducted
    function calculateFeeAmount(uint256 _amount) external view returns (uint128);

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
