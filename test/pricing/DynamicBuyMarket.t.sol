// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import {DynamicBuyMarketHarness} from "test/harnesses/DynamicBuyMarketHarness.sol";
import {DynamicBuyMarket} from "src/pricing/DynamicBuyMarket.sol";
import {IMarketBase} from "src/interfaces/IMarketBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISignatureTransfer} from "permit2/src/interfaces/ISignatureTransfer.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {PermitHash} from "permit2/src/libraries/PermitHash.sol";

contract DynamicBuyMarketTest is Test {
    bytes32 private constant _HASHED_NAME = keccak256("Permit2");
    bytes32 private constant _TYPE_HASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    ISignatureTransfer private constant PERMIT2 = ISignatureTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3); // Polygon address for fork testing
    IERC20 private constant DAI = IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063); // Polygon address for fork testing

    DynamicBuyMarketHarness private market = new DynamicBuyMarketHarness(PERMIT2, DAI);
    DynamicBuyMarketHarness private marketCloned;

    IMarketBase.MarketSettings settings = IMarketBase.MarketSettings(1, "asdf", 2, 3, vm.addr(4), 5, vm.addr(6));

    uint256 private polygonFork;
    ISignatureTransfer.PermitTransferFrom public permit;

    event MarketBaseInitialized(IMarketBase.MarketSettings settings);
    event DynamicBuyMarketInitialized(uint256 startPrice, string metadataURI);

    function setUp() public {
        polygonFork = vm.createFork("polygon", 48789677);
        marketCloned = DynamicBuyMarketHarness(Clones.clone(address(market)));
        vm.makePersistent(address(market));
        vm.makePersistent(address(marketCloned));

        permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(DAI), amount: 0}),
            nonce: 0,
            deadline: type(uint256).max
        });
    }

    function test_immutables_nonClone() public {
        assertEq(address(market.PERMIT2()), address(PERMIT2), "PERMIT2 address should be set correctly");
    }

    function test_immutables_clone() public {
        assertEq(
            address(marketCloned.PERMIT2()),
            address(PERMIT2),
            "Cloned market should have the correct PERMIT2 address"
        );
    }

    function test_Revert___DynamicBuyMarket_init_initializingNonClone() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        market.exposed___DynamicBuyMarket_init(1 ether, "https://example.com", settings);
    }

    function test___DynamicBuyMarket_init_initializingClone() public {
        vm.expectEmit(address(marketCloned));
        emit MarketBaseInitialized({settings: settings});
        emit DynamicBuyMarketInitialized({
            startPrice: 1,
            metadataURI: "https://example.com"
        });

        marketCloned.exposed___DynamicBuyMarket_init(1, "https://example.com", settings);

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
        assertEq(marketCloned.startPrice(), 1, "price is correclty set");
        assertEq(marketCloned.uri(1), "https://example.com", "tokenURI is correclty set");
    }

    function test_calculatePrice_startPrice() public {
        uint96 startPrice = 1 ether;
        marketCloned.exposed___DynamicBuyMarket_init(startPrice, "https://example.com", settings);
        assertEq(marketCloned.calculatePrice(1), startPrice);
    }

    function test_calculatePrice_startPrice_secondOutcome() public {
        vm.selectFork(polygonFork);
        uint96 startPrice = 1 ether;
        marketCloned.exposed___DynamicBuyMarket_init(startPrice, "https://example.com", settings);

        vm.warp(3);
        vote_on_outcome(1, 1 ether, makeAddr("voter"));

        assertEq(marketCloned.calculatePrice(2), startPrice);
    }

    function test_calculatePrice_dynamicPricing() public {
        vm.selectFork(polygonFork);
        uint96 startPrice = 1 ether;
        marketCloned.exposed___DynamicBuyMarket_init(startPrice, "https://example.com", settings);

        vm.warp(3);
        vote_on_outcome(1, 1 ether, makeAddr("voter"));
        vote_on_outcome(2, 0.02 ether, makeAddr("voter"));

        assertGt(marketCloned.calculatePrice(1), startPrice);
        assertLt(marketCloned.calculatePrice(2), startPrice);
    }

    function test_redeem(uint232 amount) public {
        vm.selectFork(polygonFork);
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        _settings.possibleOutcomeCount = 2;
        marketCloned.exposed___DynamicBuyMarket_init(1e18, "https://example.com", _settings);

        // verify fuzzing inputs
        vm.assume(amount > 5e17 && amount < type(uint232).max / marketCloned.BPPM());

        uint48 outcome = 2;
        address voter = makeAddr("voter");

        // buy vote on outcome
        vm.warp(3);
        uint256 shares = vote_on_outcome(outcome, amount, voter);

        // make sure market is resolved
        vm.warp(8);
        marketCloned.exposed__resolve(outcome);
        emit log_named_uint("tvl", marketCloned.tvl());
        emit log_named_uint("totalSupply", marketCloned.totalSupply(outcome));
        emit log_named_uint("sharePrice", marketCloned.payoutPerShare());

        vm.startPrank(voter);
        marketCloned.redeem(shares, voter);
        vm.stopPrank();

        assertEq(marketCloned.balanceOf(voter, outcome), 0);
        assertEq(DAI.balanceOf(voter), amount);
    }

    function vote_on_outcome(uint48 outcome, uint232 amount, address recipient) private returns (uint256 shares) {
        deal(address(DAI), recipient, amount);
        vm.startPrank(recipient);
        DAI.approve(address(marketCloned), amount);
        shares = marketCloned.voteOnOutcome(outcome, amount, recipient);
        vm.stopPrank();
    }
}
