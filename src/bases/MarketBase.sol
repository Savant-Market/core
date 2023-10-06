// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

abstract contract MarketBase is Initializable {
    uint256 public constant RATIO_BASE = 10 ^ 6;
    /// @notice The [ERC-165](https://eips.ethereum.org/EIPS/eip-165) interface ID of the contract.
    bytes4 public constant MARKET_BASE_INTERFACE_ID =
        this.calculateFeeAmount.selector ^ this.isMarketOpen.selector ^ this.isMarketResolved.selector;

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

    event MarketResolved(uint128 outcome);

    error MarketNotOpen();
    error MarketNotClosed(uint64 endDate, uint64 timestamp);
    error MarketNotResolved();
    error NotValidOutcome(uint128 givenOutcome, uint128 possibleOutcomeCount);

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
    /// @param _feePPM The fee precentage that the markets charges for each vote. In parts per million (100% = 1_000_000)
    /// @param _metadata URI to the metadata (see docs for a schema file how the metadata needs to be structured)
    /// @param _duration Duration in seconds the market will be open
    /// @param _feeRecipient Recipient address that receives the market fees
    /// @param _possibleOutcomeCount Amount of possible outcomes defined in the metadata
    /// @param _creator Creator of the market
    function __MarketBase_init(
        uint32 _feePPM,
        string memory _metadata,
        uint64 _startDate,
        uint32 _duration,
        address _feeRecipient,
        uint128 _possibleOutcomeCount,
        address _creator
    ) internal onlyInitializing {
        feePPM = _feePPM;
        metadata = _metadata;
        startDate = _startDate;
        endDate = _startDate + _duration;
        feeRecipient = _feeRecipient;
        possibleOutcomeCount = _possibleOutcomeCount;
        creator = _creator;
    }

    /// @notice Calculates the fee for the inputed amount
    /// @param _amount Amount that the fee should be calculated for
    /// @return The fee that would be deducted
    function calculateFeeAmount(uint256 _amount) public view virtual returns (uint128) {
        return uint128(_amount * RATIO_BASE / feePPM);
    }

    /// @notice Check if the market is open and ready for predictions
    /// @return Returns `true` if the market is open
    function isMarketOpen() public view virtual returns (bool) {
        if (startDate < block.timestamp) {
            return false;
        }
        if (endDate < block.timestamp) {
            return false;
        }
        return true;
    }

    /// @notice Check if the market is resolved
    /// @return Returns `true` if the market is resolved
    function isMarketResolved() public view virtual returns (bool) {
        return outcome != 0;
    }

    /// @notice Returns false if the market end date is bigger than the current time
    /// @return Returns `true` if the market is closed
    function isMarketClosed() public view returns (bool) {
        return endDate < block.timestamp;
    }

    /// @notice Checks if this or the parent contract supports an interface by its ID.
    /// @param _interfaceId The ID of the interface.
    /// @return Returns `true` if the interface is supported.
    function supportsInterface(bytes4 _interfaceId) public pure virtual returns (bool) {
        return MARKET_BASE_INTERFACE_ID == _interfaceId;
    }

    /// @notice Resolve the market to the given outcome
    /// @param _winningOutcome Outcome that the market gets resolved to
    function _resolve(uint128 _winningOutcome) internal virtual onlyValidOutcome(_winningOutcome) onlyClosedMarket {
        outcome = _winningOutcome;
        emit MarketResolved({outcome: _winningOutcome});
    }
}
