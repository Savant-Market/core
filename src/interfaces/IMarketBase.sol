// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

interface IMarketBase {
    /// @notice Vote on a certain outcome and receive the shares
    /// @param _token In which token the user pays
    /// @param _amount Amount of tokens the user spends
    /// @param _outcome Which outcome the user votes for
    function voteOnOutcome(address _token, uint256 _amount, uint128 _outcome) external;
}
