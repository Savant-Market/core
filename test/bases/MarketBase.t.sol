// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {MarketBaseHarness} from "test/harnesses/MarketBaseHarness.sol";
import {IMarketBase} from "src/interfaces/IMarketBase.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract MarketBaseTest is Test {
    MarketBaseHarness private market = new MarketBaseHarness();
    MarketBaseHarness private marketCloned;

    IMarketBase.MarketSettings settings = IMarketBase.MarketSettings(1, "asdf", 2, 3, vm.addr(4), 5, vm.addr(6));

    event MarketResolved(uint128 outcome);
    event MarketBaseInitialized(IMarketBase.MarketSettings settings);

    function setUp() public {
        marketCloned = MarketBaseHarness(Clones.clone(address(market)));
    }

    /// @notice Initializers are disabled by the constructor. So non proxy contracts should fail initializing
    function test_Revert___MarketBase_init_initializingNonClone() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        market.exposed___MarketBase_init(settings);
    }

    /// @notice The clone should be able to initialize the storage and set the values correctly
    function test___MarketBase_init_initializingClone() public {
        vm.expectEmit(address(marketCloned));
        emit MarketBaseInitialized({settings: settings});

        marketCloned.exposed___MarketBase_init(settings);
        assertEq(marketCloned.feePPM(), 1, "fee is correclty set");
        assertEq(marketCloned.metadata(), "asdf", "metadata is correclty set");
        assertEq(marketCloned.startDate(), 2, "startDate is correclty set");
        assertEq(marketCloned.endDate(), 2 + 3, "endDate is correclty set");
        assertEq(marketCloned.feeRecipient(), vm.addr(4), "feeRecipient is correclty set");
        assertEq(marketCloned.possibleOutcomeCount(), 5, "possibleOutcomeCount is correclty set");
        assertEq(marketCloned.creator(), vm.addr(6), "creator is correclty set");
        assertEq(marketCloned.tvl(), 0, "tvl is correclty set");
        assertEq(marketCloned.collectedFees(), 0, "collectedFees is correclty set");
        assertEq(marketCloned.outcome(), 0, "outcome is correclty set");
    }

    /// @notice Checks if the fee is calculated correctly. If the `_feePPM` is set to 0
    ///         the contract should return 0 too.
    function testFuzz_calculateFeeAmount_correct(uint232 _amount, uint32 _feePPM) public {
        // feePPM cannot be bigger than RATIO_BASE set in the market
        vm.assume(_feePPM < marketCloned.RATIO_BASE() + 1);

        // _amount should be bigger than 0
        vm.assume(_amount > 0);

        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = _feePPM;
        marketCloned.exposed___MarketBase_init(_settings);

        uint256 feeFromContract = marketCloned.calculateFeeAmount(_amount);

        if (_feePPM > 0) {
            uint256 expectedFeeAmount = uint256(_amount) * _feePPM / marketCloned.RATIO_BASE();
            assertEq(feeFromContract, expectedFeeAmount, "fee is correclty calculated");
        } else {
            assertEq(feeFromContract, 0, "fee to be zero because fee is set to 0");
        }
    }

    /// @notice Should return false if startDate is bigger than block.timestamp
    function test_isMarketOpen_biggerStartDate() public {
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___MarketBase_init(_settings);

        // startDate is bigger than block.timestamp
        vm.warp(1);
        assertEq(marketCloned.isMarketOpen(), false, "market should not be open");
    }

    /// @notice Should return false if endDate is smaller than block.timestamp
    function test_isMarketOpen_smallerEndDate() public {
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___MarketBase_init(_settings);

        // endDate is smaller than block.timestamp
        vm.warp(6);
        assertEq(marketCloned.isMarketOpen(), false, "market should not be open");
    }

    /// @notice Should return true if block.timestamp is between startDate and endDate
    function test_isMarketOpen_timestampInBoundaries() public {
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___MarketBase_init(_settings);

        // block.timestamp is between endDate and startDate
        vm.warp(4);
        assertEq(marketCloned.isMarketOpen(), true, "market should be open");
    }

    /// @notice Should return true if block.timestamp is equal to startDate
    function test_isMarketOpen_startDateIsEqual() public {
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___MarketBase_init(_settings);

        // block.timestamp is equal to startDate
        vm.warp(marketCloned.startDate());
        assertEq(marketCloned.isMarketOpen(), true, "market should be open");
    }

    /// @notice Should return true if block.timestamp is equal to endDate
    function test_isMarketOpen_endDateIsEqual() public {
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___MarketBase_init(_settings);

        // block.timestamp is equal to endDate
        vm.warp(marketCloned.endDate());
        assertEq(marketCloned.isMarketOpen(), true, "market should be open");
    }

    /// @notice Market shouldn't be resolved by default
    function test_isMarketResolved_default() public {
        marketCloned.exposed___MarketBase_init(settings);

        assertEq(marketCloned.isMarketResolved(), false, "market should not be resolved");
    }

    /// @notice Market should be resolved if outcome is bigger than 0
    function test_isMarketResolved_biggerThenZero() public {
        marketCloned.exposed___MarketBase_init(settings);

        marketCloned.workaround_setOutcome(2);

        assertEq(marketCloned.isMarketResolved(), true, "market should be resolved");
    }

    /// @notice Market is not closed block.timestamp is smaller than endDate
    function test_isMarketClosed_smallerThenEndDate() public {
        marketCloned.exposed___MarketBase_init(settings);

        // market is not closed
        vm.warp(2);
        assertEq(marketCloned.isMarketClosed(), false, "market should not be closed");
    }

    /// @notice Market is not closed if block.timestamp is equal to endDate
    function test_isMarketClosed_equalThenEndDate() public {
        marketCloned.exposed___MarketBase_init(settings);

        // market is not closed if endDate = block.timestamp
        vm.warp(marketCloned.endDate());
        assertEq(marketCloned.isMarketClosed(), false, "market should not be closed");
    }

    /// @notice Market is closed if block.timestamp is bigger then endDate
    function test_isMarketClosed_biggerThenEndDate() public {
        marketCloned.exposed___MarketBase_init(settings);

        // market is closed
        vm.warp(marketCloned.endDate() + 1);
        assertEq(marketCloned.isMarketClosed(), true, "market should be closed");
    }

    /// @notice check if market exports the correct interface
    function test_supportsInterface_ERC165() public {
        // should support the ERC165 interface
        assertEq(marketCloned.supportsInterface(0x01ffc9a7), true, "should support the interface");
    }

    /// @notice check if market exports the correct interface
    function test_supportsInterface_IMarketBase() public {
        // should support the ERC165 interface of IMarketBase
        assertEq(marketCloned.supportsInterface(type(IMarketBase).interfaceId), true, "should support the interface");
    }

    /// @notice should return false
    function test_supportsInterface_InvalidInterface() public {
        // should not support an invalid interface
        assertEq(marketCloned.supportsInterface(0xffffffff), false, "should not support the interface");
    }

    /// @notice should revert if outcome is invalid
    function test_Revert_resolve_invalidOutcome() public {
        marketCloned.exposed___MarketBase_init(settings);

        uint48 invalidOutcome = type(uint48).max - 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                IMarketBase.InvalidOutcome.selector, invalidOutcome, marketCloned.possibleOutcomeCount()
            )
        );
        marketCloned.exposed_resolve(invalidOutcome);
    }

    /// @notice should revert if market is not closed
    function test_Revert_resolve_notClosed() public {
        marketCloned.exposed___MarketBase_init(settings);
        uint48 validOutcome = 1;
        vm.warp(3);

        vm.expectRevert(abi.encodeWithSelector(IMarketBase.MarketNotClosed.selector, marketCloned.endDate(), 3));
        marketCloned.exposed_resolve(validOutcome);
    }

    /// @notice should set the outcome and emit MarketResolved
    function test_resolve_valid() public {
        marketCloned.exposed___MarketBase_init(settings);
        uint48 validOutcome = 1;
        vm.warp(6);

        vm.expectEmit(address(marketCloned));
        emit MarketResolved(validOutcome);
        marketCloned.exposed_resolve(validOutcome);
        assertEq(marketCloned.outcome(), validOutcome, "should set the outcome correctly");
    }
}
