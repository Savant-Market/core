// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {FixedPriceMarketHarness} from "test/harnesses/FixedPriceMarketHarness.sol";
import {IMarketBase} from "src/interfaces/IMarketBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract FixedPriceMarketTest is Test {
    IERC20 private constant DAI = IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063); // Polygon address for fork testing
    IAllowanceTransfer private constant PERMIT2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3); // Polygon address for fork testing

    FixedPriceMarketHarness private market = new FixedPriceMarketHarness(DAI, PERMIT2);
    FixedPriceMarketHarness private marketCloned;

    IMarketBase.MarketSettings settings = IMarketBase.MarketSettings(1, "asdf", 2, 3, vm.addr(4), 5, vm.addr(6));

    uint256 private polygonFork;

    event FixedPriceMarketInitialized(uint256 price, string metadataURI);
    event MarketBaseInitialized(IMarketBase.MarketSettings settings);
    event Voted(address indexed voter, address indexed recipient, uint256 outcome, uint256 amountOfShares);

    function setUp() public {
        polygonFork = vm.createFork("polygon", 48789677);
        marketCloned = FixedPriceMarketHarness(Clones.clone(address(market)));
        vm.makePersistent(address(market));
        vm.makePersistent(address(marketCloned));
    }

    function test_immutables_nonClone() public {
        assertEq(address(market.DAI()), address(DAI), "DAI address should be set correctly");
        assertEq(address(market.PERMIT2()), address(PERMIT2), "PERMIT2    address should be set correctly");
    }

    function test_immutables_clone() public {
        assertEq(address(marketCloned.DAI()), address(DAI), "Cloned market should have the correct DAI address");
        assertEq(
            address(marketCloned.PERMIT2()),
            address(PERMIT2),
            "Cloned market should have the correct PERMIT2    address"
        );
    }

    function test_Revert___FixedPriceMarket_init_initializingNonClone() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        market.exposed___FixedPriceMarket_init(1, "https://example.com", settings);
    }

    function test___FixedPriceMarket_init_initializingClone() public {
        vm.expectEmit(address(marketCloned));
        emit MarketBaseInitialized({settings: settings});
        emit FixedPriceMarketInitialized({price: 1, metadataURI: "https://example.com"});

        marketCloned.exposed___FixedPriceMarket_init(1, "https://example.com", settings);

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
        assertEq(marketCloned.price(), 1, "price is correclty set");
        assertEq(marketCloned.uri(1), "https://example.com", "tokenURI is correclty set");
    }

    function test_voteOnOutcome_emitEvent() public {
        vm.selectFork(polygonFork);

        // initialize the market
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___FixedPriceMarket_init(1e18, "https://example.com", _settings);

        address recipient = makeAddr("recipient");
        address voter = makeAddr("voter");
        uint256 amount = 1e18;
        uint128 outcome = 1;

        // make sure market is open
        vm.warp(3);

        deal(address(DAI), voter, amount);
        vm.startPrank(voter);
        DAI.approve(address(marketCloned), amount);

        vm.expectEmit(address(marketCloned));
        emit Voted({voter: voter, recipient: recipient, outcome: outcome, amountOfShares: amount});
        marketCloned.voteOnOutcome(outcome, amount, recipient);
        vm.stopPrank();
    }

    function test_voteOnOutcome_takeFunds() public {
        vm.selectFork(polygonFork);

        // initialize the market
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___FixedPriceMarket_init(1e18, "https://example.com", _settings);

        address recipient = makeAddr("recipient");
        address voter = makeAddr("voter");
        uint256 amount = 1e18;
        uint128 outcome = 1;

        // test that a clean slate is given
        assertEq(DAI.balanceOf(address(marketCloned)), 0);
        assertEq(DAI.balanceOf(voter), 0);
        assertEq(DAI.balanceOf(recipient), 0);

        // make sure market is open
        vm.warp(3);

        deal(address(DAI), voter, amount);
        vm.startPrank(voter);
        DAI.approve(address(marketCloned), amount);
        marketCloned.voteOnOutcome(outcome, amount, recipient);
        vm.stopPrank();

        assertEq(DAI.balanceOf(address(marketCloned)), amount);
        assertEq(DAI.balanceOf(voter), 0);
        assertEq(DAI.balanceOf(recipient), 0);
    }

    function test_voteOnOutcome_mintShares() public {
                vm.selectFork(polygonFork);

        // initialize the market
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___FixedPriceMarket_init(1e18, "https://example.com", _settings);

        address recipient = makeAddr("recipient");
        address voter = makeAddr("voter");
        uint256 amount = 1e18;
        uint128 outcome = 1;

        // test that a clean slate is given
        assertEq(marketCloned.balanceOf(recipient, outcome), 0);

        // make sure market is open
        vm.warp(3);

        deal(address(DAI), voter, amount);
        vm.startPrank(voter);
        DAI.approve(address(marketCloned), amount);
        marketCloned.voteOnOutcome(outcome, amount, recipient);
        vm.stopPrank();

        assertEq(marketCloned.balanceOf(recipient, outcome), amount);
    }
}
