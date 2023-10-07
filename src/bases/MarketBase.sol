// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../interfaces/IMarketBase.sol";

abstract contract MarketBase is Initializable, ERC165, IMarketBase {
    uint256 public constant RATIO_BASE = 10 ^ 6;
    /// @notice The [ERC-165](https://eips.ethereum.org/EIPS/eip-165) interface ID of the contract.

    address public creator;
    uint256 public tvl;
    uint128 public collectedFees;
    uint32 public feePPM;
    uint64 public startDate;
    uint64 public endDate;
    uint128 public possibleOutcomeCount;
    uint128 public outcome;
    string public metadata;
    address public feeRecipient;

    /// @notice Checks if the market is open
    modifier onlyOpenMarket() {
        if (!isMarketOpen()) {
            revert MarketNotOpen();
        }
        _;
    }

    /// @notice Checks if the market is closed
    modifier onlyClosedMarket() {
        if (!isMarketClosed()) {
            revert MarketNotClosed({endDate: endDate, timestamp: uint64(block.timestamp)});
        }
        _;
    }

    /// @notice Checks if the market is resolved
    modifier onlyResolvedMarket() {
        if (!isMarketResolved()) {
            revert MarketNotResolved();
        }
        _;
    }

    /// @notice Checks if an outcome is valid
    modifier onlyValidOutcome(uint128 _outcome) {
        uint128 _possibleOutcomeCount = possibleOutcomeCount;
        if (_outcome == 0 || _outcome > possibleOutcomeCount) {
            revert NotValidOutcome({givenOutcome: _outcome, possibleOutcomeCount: _possibleOutcomeCount});
        }
        _;
    }

    /// @notice Disabled initializers because a deployed contract should only be used in combination with a minimal proxy contract
    /// @dev Use EIP-1167 for the minimal proxy
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize function to initialize the storage of the minimal proxy contract
    /// @param _settings Settings used to initialize the market
    function __MarketBase_init(MarketSettings calldata _settings) internal onlyInitializing {
        feePPM = _settings.feePPM;
        metadata = _settings.metadata;
        startDate = _settings.startDate;
        endDate = _settings.startDate + _settings.duration;
        feeRecipient = _settings.feeRecipient;
        possibleOutcomeCount = _settings.possibleOutcomeCount;
        creator = _settings.creator;
    }

    /// @inheritdoc IMarketBase
    function calculateFeeAmount(uint256 _amount) public view virtual returns (uint128) {
        // If no fee is set the amount is always 0
        if (feePPM == 0) return 0;
        return uint128(_amount * feePPM / RATIO_BASE);
    }

    /// @inheritdoc IMarketBase
    function isMarketOpen() public view virtual returns (bool) {
        if (startDate > block.timestamp) {
            return false;
        }
        if (endDate < block.timestamp) {
            return false;
        }
        return true;
    }

    /// @inheritdoc IMarketBase
    function isMarketResolved() public view virtual returns (bool) {
        return outcome != 0;
    }

    /// @inheritdoc IMarketBase
    function isMarketClosed() public view virtual returns (bool) {
        return endDate < block.timestamp;
    }

    /// @notice Checks if this or the parent contract supports an interface by its ID.
    /// @param _interfaceId The ID of the interface.
    /// @return Returns `true` if the interface is supported.
    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return type(IMarketBase).interfaceId == _interfaceId || super.supportsInterface(_interfaceId);
    }

    /// @notice Resolve the market to the given outcome
    /// @param _winningOutcome Outcome that the market gets resolved to
    function _resolve(uint128 _winningOutcome) internal virtual onlyValidOutcome(_winningOutcome) onlyClosedMarket {
        outcome = _winningOutcome;
        emit MarketResolved({outcome: _winningOutcome});
    }
}
