// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../helpers/MarketBaseNonAbstract.sol";
import "../../src/interfaces/IMarketBase.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract MarketBaseTest is Test {
    MarketBaseNonAbstract private market = new MarketBaseNonAbstract();
    MarketBaseNonAbstract private marketCloned;

    IMarketBase.MarketSettings settings = IMarketBase.MarketSettings(1, "asdf", 2, 3, vm.addr(4), 5, vm.addr(6));

    event MarketResolved(uint128 outcome);
    event MarketBaseInitialized(IMarketBase.MarketSettings settings);

    function setUp() public {
        marketCloned = MarketBaseNonAbstract(Clones.clone(address(market)));
    }

    /// @notice Initializers are disabled by the constructor. So non proxy contracts should fail initializing
    function test_initializingNonClone() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        market.initialize(settings);
    }

    /// @notice The clone should be able to initialize the storage and set the values correctly
    function test_initializingClone() public {
        vm.expectEmit(address(marketCloned));
        emit MarketBaseInitialized({settings: settings});

        marketCloned.initialize(settings);
        assertEq(marketCloned.feePPM(), 1);
        assertEq(marketCloned.metadata(), "asdf");
        assertEq(marketCloned.startDate(), 2);
        assertEq(marketCloned.endDate(), 2 + 3);
        assertEq(marketCloned.feeRecipient(), vm.addr(4));
        assertEq(marketCloned.possibleOutcomeCount(), 5);
        assertEq(marketCloned.creator(), vm.addr(6));
        assertEq(marketCloned.tvl(), 0);
        assertEq(marketCloned.collectedFees(), 0);
        assertEq(marketCloned.outcome(), 0);
    }

    /// @notice Checks if the fee is calculated correctly. If the `_feePPM` is set to 0
    ///         the contract should return 0 too.
    function test_calculatesCorrectFeeAmount(uint256 _amount, uint32 _feePPM) public {
        // feePPM cannot be bigger than RATIO_BASE set in the market
        vm.assume(_feePPM < marketCloned.RATIO_BASE() + 1);

        // _amount should be bigger than 0 and lower than the max uint256 divided by the RATIO_BASE because the RATIO_BASE
        // gets added during the fee calculation
        vm.assume(_amount > 0);
        vm.assume(_amount < type(uint256).max / marketCloned.RATIO_BASE());

        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = _feePPM;
        marketCloned.initialize(_settings);

        uint128 feeFromContract = marketCloned.calculateFeeAmount(_amount);

        if (_feePPM > 0) {
            uint128 expectedFeeAmount = uint128(_amount * _feePPM / marketCloned.RATIO_BASE());
            assertEq(feeFromContract, expectedFeeAmount);
        } else {
            assertEq(feeFromContract, 0);
        }
    }

    /// @notice Should return false if startDate is bigger than block.timestamp
    ///         Should return false if endDate is smaller than block.timestamp
    ///         Should return true if block.timestamp is between startDate and endDate
    function test_isMarketOpen() public {
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.initialize(_settings);

        // startDate is bigger than block.timestamp
        vm.warp(1);
        assertEq(marketCloned.isMarketOpen(), false);

        // endDate is smaller than block.timestamp
        vm.warp(6);
        assertEq(marketCloned.isMarketOpen(), false);

        // block.timestamp is between endDate and startDate
        vm.warp(4);
        assertEq(marketCloned.isMarketOpen(), true);

        // block.timestamp is equal to startDate
        vm.warp(marketCloned.startDate());
        assertEq(marketCloned.isMarketOpen(), true);

        // block.timestamp is equal to endDate
        vm.warp(marketCloned.endDate());
        assertEq(marketCloned.isMarketOpen(), true);
    }

    /// @notice Market shouldn't be resolved by default
    ///         Market should be resolved if outcome is bigger than 0
    function test_isMarketResolved() public {
        marketCloned.initialize(settings);

        assertEq(marketCloned.isMarketResolved(), false);

        marketCloned.setOutcome(2);

        assertEq(marketCloned.isMarketResolved(), true);
    }

    /// @notice Market is closed if endDate is smaller than block.timestamp
    function test_isMarketClosed() public {
        marketCloned.initialize(settings);

        // market is not closed
        vm.warp(2);
        assertEq(marketCloned.isMarketClosed(), false);

        // market is not closed if endDate = block.timestamp
        vm.warp(marketCloned.endDate());
        assertEq(marketCloned.isMarketClosed(), false);

        // market is closed
        vm.warp(marketCloned.endDate() + 1);
        assertEq(marketCloned.isMarketClosed(), true);
    }

    /// @notice check if market exports the correct interface
    function test_supportsInterface() public {
        // should support the ERC165 interface
        assertEq(marketCloned.supportsInterface(0x01ffc9a7), true);

        // should support the ERC165 interface of IMarketBase
        assertEq(marketCloned.supportsInterface(type(IMarketBase).interfaceId), true);

        // should not support an invalid interface
        assertEq(marketCloned.supportsInterface(0xffffffff), false);
    }

    /// @notice should revert if outcome is invalid
    function test_invalidOutcomeResolve() public {
        marketCloned.initialize(settings);

        uint128 invalidOutcome = type(uint128).max - 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                IMarketBase.NotValidOutcome.selector, invalidOutcome, marketCloned.possibleOutcomeCount()
            )
        );
        marketCloned.resolve(invalidOutcome);
    }

    /// @notice should revert if market is not closed
    function test_notClosedResolve() public {
        marketCloned.initialize(settings);
        uint128 validOutcome = 1;
        vm.warp(3);

        vm.expectRevert(abi.encodeWithSelector(IMarketBase.MarketNotClosed.selector, marketCloned.endDate(), 3));
        marketCloned.resolve(validOutcome);
    }

    /// @notice should set the outcome and emit MarketResolved
    function test_resolve() public {
        marketCloned.initialize(settings);
        uint128 validOutcome = 1;
        vm.warp(6);

        vm.expectEmit(address(marketCloned));
        emit MarketResolved(validOutcome);
        marketCloned.resolve(validOutcome);
        assertEq(marketCloned.outcome(), validOutcome);
    }
}
