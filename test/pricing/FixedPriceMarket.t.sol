// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import {FixedPriceMarketHarness} from "test/harnesses/FixedPriceMarketHarness.sol";
import {FixedPriceMarket} from "src/pricing/FixedPriceMarket.sol";
import {IMarketBase} from "src/interfaces/IMarketBase.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISignatureTransfer} from "permit2/src/interfaces/ISignatureTransfer.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {PermitHash} from "permit2/src/libraries/PermitHash.sol";

contract FixedPriceMarketTest is Test {
    bytes32 private constant _HASHED_NAME = keccak256("Permit2");
    bytes32 private constant _TYPE_HASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    IERC20 private constant DAI = IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063); // Polygon address for fork testing
    ISignatureTransfer private constant PERMIT2 = ISignatureTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3); // Polygon address for fork testing

    FixedPriceMarketHarness private market = new FixedPriceMarketHarness(DAI, PERMIT2);
    FixedPriceMarketHarness private marketCloned;

    IMarketBase.MarketSettings settings = IMarketBase.MarketSettings(1, "asdf", 2, 3, vm.addr(4), 5, vm.addr(6));

    uint256 private polygonFork;

    ISignatureTransfer.PermitTransferFrom public permit;

    event FixedPriceMarketInitialized(uint256 price, string metadataURI);
    event MarketBaseInitialized(IMarketBase.MarketSettings settings);
    event Voted(address indexed voter, address indexed recipient, uint256 outcome, uint256 amountOfShares);
    event SharesRedeemed(
        address indexed holder, address indexed recipient, uint256 amountOfShares, uint256 payoutAmount
    );

    function setUp() public {
        polygonFork = vm.createFork("polygon", 48789677);
        marketCloned = FixedPriceMarketHarness(Clones.clone(address(market)));
        vm.makePersistent(address(market));
        vm.makePersistent(address(marketCloned));

        permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(DAI), amount: 0}),
            nonce: 0,
            deadline: type(uint256).max
        });
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

    function test_Revert___FixedPriceMarket_init_invalidPrice() public {
        vm.expectRevert(abi.encodeWithSelector(FixedPriceMarket.InvalidPrice.selector, 0));
        marketCloned.exposed___FixedPriceMarket_init(0, "https://example.com", settings);
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

    function test_voteOnOutcome_emitEvent(uint232 amount) public {
        vm.selectFork(polygonFork);

        // verify fuzzing inputs
        vm.assume(amount > 0 && amount < type(uint232).max / marketCloned.RATIO_BASE());

        // initialize the market
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", _settings);

        address recipient = makeAddr("recipient");
        address voter = makeAddr("voter");
        uint48 outcome = 1;

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

    function test_voteOnOutcome_takeFunds(uint232 amount) public {
        vm.selectFork(polygonFork);

        // verify fuzzing inputs
        vm.assume(amount > 0 && amount < type(uint232).max / marketCloned.RATIO_BASE());

        // initialize the market
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", _settings);

        address recipient = makeAddr("recipient");
        address voter = makeAddr("voter");
        uint48 outcome = 1;

        // test that a clean slate is given
        assertEq(DAI.balanceOf(address(marketCloned)), 0);
        assertEq(DAI.balanceOf(voter), 0);
        assertEq(DAI.balanceOf(recipient), 0);

        // make sure market is open
        vm.warp(3);

        deal(address(DAI), voter, amount);
        assertEq(DAI.balanceOf(voter), amount);

        vm.startPrank(voter);
        DAI.approve(address(marketCloned), amount);
        marketCloned.voteOnOutcome(outcome, amount, recipient);
        vm.stopPrank();

        assertEq(DAI.balanceOf(address(marketCloned)), amount);
        assertEq(DAI.balanceOf(voter), 0);
        assertEq(DAI.balanceOf(recipient), 0);
    }

    function test_voteOnOutcome_mintShares(uint232 amount) public {
        vm.selectFork(polygonFork);

        // verify fuzzing inputs
        vm.assume(amount > 0 && amount < type(uint232).max / marketCloned.RATIO_BASE());

        // initialize the market
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", _settings);

        address recipient = makeAddr("recipient");
        address voter = makeAddr("voter");
        uint48 outcome = 1;

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

    function test_voteOnOutcome_deductFee(uint232 amount, uint32 feePPM) public {
        vm.selectFork(polygonFork);

        // verify fuzzing inputs
        vm.assume(amount > 0 && amount < type(uint232).max / marketCloned.RATIO_BASE());
        vm.assume(feePPM > 0 && feePPM < marketCloned.RATIO_BASE() + 1);

        // initialize the market
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = feePPM;
        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", _settings);

        address recipient = makeAddr("recipient");
        address voter = makeAddr("voter");
        uint48 outcome = 1;
        uint256 feeAmount = marketCloned.calculateFeeAmount(amount);

        // test that a clean slate is given
        assertEq(marketCloned.balanceOf(recipient, outcome), 0);

        // make sure market is open
        vm.warp(3);

        deal(address(DAI), voter, amount);
        vm.startPrank(voter);
        DAI.approve(address(marketCloned), amount);
        marketCloned.voteOnOutcome(outcome, amount, recipient);
        vm.stopPrank();

        assertEq(marketCloned.tvl(), amount - feeAmount);
        assertEq(marketCloned.collectedFees(), feeAmount);
        assertEq(DAI.balanceOf(address(marketCloned)), amount); // The market should store the fees
    }

    function test_voteOnOutcome_amountTooBigError() public {
        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", settings);
        uint232 amount = type(uint232).max / marketCloned.RATIO_BASE() + 1;
        vm.expectRevert(FixedPriceMarket.AmountTooBig.selector);
        marketCloned.voteOnOutcome(1, amount, address(0));
    }

    function test_permitVoteOnOutcome_invalidToken() public {
        ISignatureTransfer.PermitTransferFrom memory _permit = permit;
        _permit.permitted.token = address(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                FixedPriceMarket.InvalidToken.selector, _permit.permitted.token, address(marketCloned.DAI())
            )
        );
        marketCloned.permitVoteOnOutcome(_permit, new bytes(0), 1, makeAddr("recipient"));
    }

    function test_permitVoteOnOutcome_emitEvent(uint192 amount, uint48 outcome) public {
        vm.selectFork(polygonFork);

        // initialize the market
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", _settings);

        // verify fuzzing inputs
        vm.assume(amount > 0 && amount < type(uint232).max / marketCloned.RATIO_BASE());
        outcome = uint48(bound(outcome, 1, marketCloned.possibleOutcomeCount()));

        // prepare wallets
        address recipient = makeAddr("recipient");
        Vm.Wallet memory voter = vm.createWallet("voter");
        deal(address(DAI), voter.addr, amount);

        // prepare permit values
        ISignatureTransfer.PermitTransferFrom memory _permit = permit;
        _permit.permitted.amount = amount;

        // make sure market is open
        vm.warp(3);

        vm.startPrank(voter.addr);
        DAI.approve(address(PERMIT2), type(uint256).max);

        vm.expectEmit(address(marketCloned));
        emit Voted({voter: voter.addr, recipient: recipient, outcome: outcome, amountOfShares: amount});
        marketCloned.permitVoteOnOutcome(_permit, get_permit_signature(voter, _permit), outcome, recipient);
        vm.stopPrank();
    }

    function test_permitVoteOnOutcome_takeFunds(uint232 amount) public {
        vm.selectFork(polygonFork);

        // verify fuzzing inputs
        vm.assume(amount > 0 && amount < type(uint232).max / marketCloned.RATIO_BASE());

        // initialize the market
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", _settings);
        uint48 outcome = 1;

        // prepare wallets
        address recipient = makeAddr("recipient");
        Vm.Wallet memory voter = vm.createWallet("voter");

        // prepare permit values
        ISignatureTransfer.PermitTransferFrom memory _permit = permit;
        _permit.permitted.amount = amount;

        // test that a clean slate is given
        assertEq(DAI.balanceOf(address(marketCloned)), 0);
        assertEq(DAI.balanceOf(voter.addr), 0);
        assertEq(DAI.balanceOf(recipient), 0);

        // make sure market is open
        vm.warp(3);

        deal(address(DAI), voter.addr, amount);
        assertEq(DAI.balanceOf(voter.addr), amount);

        vm.startPrank(voter.addr);
        DAI.approve(address(PERMIT2), type(uint256).max);
        marketCloned.permitVoteOnOutcome(_permit, get_permit_signature(voter, _permit), outcome, recipient);
        vm.stopPrank();

        assertEq(DAI.balanceOf(address(marketCloned)), amount);
        assertEq(DAI.balanceOf(voter.addr), 0);
        assertEq(DAI.balanceOf(recipient), 0);
    }

    function test_permitVoteOnOutcome_mintShares(uint232 amount) public {
        vm.selectFork(polygonFork);

        // verify fuzzing inputs
        vm.assume(amount > 0 && amount < type(uint232).max / marketCloned.RATIO_BASE());

        // initialize the market
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", _settings);
        uint48 outcome = 1;

        // prepare wallets
        address recipient = makeAddr("recipient");
        Vm.Wallet memory voter = vm.createWallet("voter");

        // prepare permit values
        ISignatureTransfer.PermitTransferFrom memory _permit = permit;
        _permit.permitted.amount = amount;

        // test that a clean slate is given
        assertEq(marketCloned.balanceOf(recipient, outcome), 0);

        // make sure market is open
        vm.warp(3);

        deal(address(DAI), voter.addr, amount);
        vm.startPrank(voter.addr);
        DAI.approve(address(PERMIT2), type(uint256).max);
        marketCloned.permitVoteOnOutcome(_permit, get_permit_signature(voter, _permit), outcome, recipient);
        vm.stopPrank();

        assertEq(marketCloned.balanceOf(recipient, outcome), amount);
    }

    function test_permitVoteOnOutcome_deductFee(uint232 amount, uint32 feePPM) public {
        vm.selectFork(polygonFork);

        // verify fuzzing inputs
        vm.assume(amount > 0 && amount < type(uint232).max / marketCloned.RATIO_BASE());
        vm.assume(feePPM > 0 && feePPM < marketCloned.RATIO_BASE() + 1);

        // initialize the market
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = feePPM;
        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", _settings);

        // prepare wallets
        address recipient = makeAddr("recipient");
        Vm.Wallet memory voter = vm.createWallet("voter");
        uint48 outcome = 1;
        uint256 feeAmount = marketCloned.calculateFeeAmount(amount);

        // prepare permit values
        ISignatureTransfer.PermitTransferFrom memory _permit = permit;
        _permit.permitted.amount = amount;

        // test that a clean slate is given
        assertEq(marketCloned.balanceOf(recipient, outcome), 0);

        // make sure market is open
        vm.warp(3);

        deal(address(DAI), voter.addr, amount);
        vm.startPrank(voter.addr);
        DAI.approve(address(PERMIT2), type(uint256).max);
        marketCloned.permitVoteOnOutcome(_permit, get_permit_signature(voter, _permit), outcome, recipient);
        vm.stopPrank();

        assertEq(marketCloned.tvl(), amount - feeAmount);
        assertEq(marketCloned.collectedFees(), feeAmount);
        assertEq(DAI.balanceOf(address(marketCloned)), amount); // The market should store the fees
    }

    function test_permitVoteOnOutcome_amountTooBig() public {
        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", settings);

        // prepare permit values
        ISignatureTransfer.PermitTransferFrom memory _permit = permit;
        _permit.permitted.amount = type(uint232).max / marketCloned.RATIO_BASE() + 1;

        vm.expectRevert(FixedPriceMarket.AmountTooBig.selector);
        marketCloned.permitVoteOnOutcome(
            _permit, get_permit_signature(vm.createWallet("voter"), _permit), 1, address(0)
        );
    }

    function test_redeem_notResolved(uint232 amount, uint48 outcome) public {
        vm.selectFork(polygonFork);

        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", settings);

        // verify fuzzing inputs
        vm.assume(amount > 0 && amount < type(uint232).max / marketCloned.RATIO_BASE());
        outcome = uint48(bound(outcome, 1, marketCloned.possibleOutcomeCount()));

        // make sure market is open
        vm.warp(3);

        address voter = makeAddr("voter");
        vote_on_outcome(outcome, amount, voter);

        uint256 balanceOfVote = marketCloned.balanceOf(voter, outcome);
        vm.expectRevert(IMarketBase.MarketNotResolved.selector);
        marketCloned.redeem(balanceOfVote, voter);
    }

    function test_redeem_NotEnoughShares() public {
        vm.selectFork(polygonFork);
        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", settings);

        uint232 amount = 1 ether;
        uint48 outcome = 2;

        // make sure market is resolved
        vm.warp(8);
        marketCloned.exposed__resolve(outcome);

        address voter = makeAddr("voter");
        vm.expectRevert(abi.encodeWithSelector(FixedPriceMarket.NotEnoughShares.selector, amount, 0));

        marketCloned.redeem(amount, voter);
    }

    function test_redeem_burnShares(uint224 amount) public {
        vm.selectFork(polygonFork);
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", _settings);

        // verify fuzzing inputs
        vm.assume(amount > 0 && amount < type(uint232).max / marketCloned.RATIO_BASE());

        uint48 outcome = 2;
        address voter = makeAddr("voter");

        // buy vote on outcome
        vm.warp(3);
        uint256 shares = vote_on_outcome(outcome, amount, voter);
        uint256 totalSupplyOutcome = marketCloned.totalSupply(outcome);
        assertEq(shares, amount);
        assertEq(marketCloned.balanceOf(voter, outcome), shares);

        // make sure market is resolved
        vm.warp(8);
        marketCloned.exposed__resolve(outcome);

        vm.startPrank(voter);
        marketCloned.redeem(amount, voter);
        assertEq(marketCloned.balanceOf(voter, outcome), 0);
        assertEq(marketCloned.totalSupply(outcome), totalSupplyOutcome - amount);
        vm.stopPrank();
    }

    function test_redeem_transfersPayout(uint224 amount) public {
        vm.selectFork(polygonFork);
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", _settings);

        // verify fuzzing inputs
        vm.assume(amount > 0 && amount < type(uint232).max / marketCloned.RATIO_BASE());

        uint48 outcome = 2;
        address voter = makeAddr("voter");

        // buy vote on outcome
        vm.warp(3);
        uint256 shares = vote_on_outcome(outcome, amount, voter);
        assertEq(shares, amount);
        assertEq(marketCloned.balanceOf(voter, outcome), shares);

        // make sure market is resolved
        vm.warp(8);
        marketCloned.exposed__resolve(outcome);

        uint256 voterBalanceBefore = DAI.balanceOf(voter);
        uint256 marketBalanceBefore = DAI.balanceOf(address(marketCloned));
        vm.startPrank(voter);
        marketCloned.redeem(amount, voter);
        assertEq(DAI.balanceOf(voter), voterBalanceBefore + amount);
        assertEq(DAI.balanceOf(address(marketCloned)), marketBalanceBefore - amount);
        vm.stopPrank();
    }

    function test_redeem_emitSharesRedeemed(uint224 amount) public {
        vm.selectFork(polygonFork);
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", _settings);

        // verify fuzzing inputs
        vm.assume(amount > 0 && amount < type(uint232).max / marketCloned.RATIO_BASE());

        uint48 outcome = 2;
        address voter = makeAddr("voter");

        // buy vote on outcome
        vm.warp(3);
        uint256 shares = vote_on_outcome(outcome, amount, voter);
        assertEq(shares, amount);
        assertEq(marketCloned.balanceOf(voter, outcome), shares);

        // make sure market is resolved
        vm.warp(8);
        marketCloned.exposed__resolve(outcome);

        vm.startPrank(voter);
        vm.expectEmit(address(marketCloned));
        emit SharesRedeemed(voter, voter, amount, amount);
        marketCloned.redeem(amount, voter);
        vm.stopPrank();
    }

    function test_burn_shouldRedeem(uint232 amount) public {
        vm.selectFork(polygonFork);
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", _settings);

        // verify fuzzing inputs
        vm.assume(amount > 0 && amount < type(uint232).max / marketCloned.RATIO_BASE());

        uint48 outcome = 2;
        address voter = makeAddr("voter");

        // buy vote on outcome
        vm.warp(3);
        uint256 shares = vote_on_outcome(outcome, amount, voter);
        assertEq(shares, amount);
        assertEq(marketCloned.balanceOf(voter, outcome), shares);

        // make sure market is resolved
        vm.warp(8);
        marketCloned.exposed__resolve(outcome);

        vm.startPrank(voter);
        vm.expectEmit(address(marketCloned));
        emit SharesRedeemed(voter, voter, amount, amount);
        marketCloned.burn(outcome, amount);
        vm.stopPrank();
    }

    function test_burn_shouldOnlyBurn(uint232 amount) public {
        vm.selectFork(polygonFork);
        IMarketBase.MarketSettings memory _settings = settings;
        _settings.feePPM = 0;
        marketCloned.exposed___FixedPriceMarket_init(1e5, "https://example.com", _settings);

        // verify fuzzing inputs
        vm.assume(amount > 0 && amount < type(uint232).max / marketCloned.RATIO_BASE());

        uint48 outcome = 2;
        address voter = makeAddr("voter");

        // buy vote on outcome
        vm.warp(3);
        uint256 shares = vote_on_outcome(outcome, amount, voter);
        assertEq(shares, amount);
        assertEq(marketCloned.balanceOf(voter, outcome), shares);

        // make sure market is resolved
        vm.warp(8);
        marketCloned.exposed__resolve(1);

        vm.startPrank(voter);
        marketCloned.burn(outcome, amount);
        vm.stopPrank();

        assertEq(marketCloned.balanceOf(voter, outcome), 0);
        assertEq(DAI.balanceOf(voter), 0);
    }

    /// @notice check if market exports the correct interface
    function test_supportsInterface_ERC165() public {
        // should support the ERC165 interface
        assertEq(marketCloned.supportsInterface(0x01ffc9a7), true, "should support ERC165 the interface");
    }

    /// @notice check if market exports the base interface
    function test_supportsInterface_IMarketBase() public {
        // should support the ERC165 interface of IMarketBase
        assertEq(
            marketCloned.supportsInterface(type(IMarketBase).interfaceId),
            true,
            "should support the IBaseMarket interface"
        );
    }

    /// @notice check if market exports the correct interface
    function test_supportsInterface_IFixedPriceMarket() public {
        // should support the ERC165 interface of IMarketBase
        assertEq(
            marketCloned.supportsInterface(marketCloned.FIXED_PRICE_MARKET_INTERFACE_ID()),
            true,
            "should support the FixedPriceMarket interface"
        );
    }

    /// @notice should return false
    function test_supportsInterface_InvalidInterface() public {
        // should not support an invalid interface
        assertEq(marketCloned.supportsInterface(0xffffffff), false, "should not support the interface");
    }

    // HELPERS
    function vote_on_outcome(uint48 outcome, uint232 amount, address recipient) private returns (uint256 shares) {
        deal(address(DAI), recipient, amount);
        vm.startPrank(recipient);
        DAI.approve(address(marketCloned), amount);
        shares = marketCloned.voteOnOutcome(outcome, amount, recipient);
        vm.stopPrank();
    }

    function get_permit_signature(Vm.Wallet memory _wallet, ISignatureTransfer.PermitTransferFrom memory _permit)
        private
        returns (bytes memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _wallet,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    keccak256(abi.encode(_TYPE_HASH, _HASHED_NAME, block.chainid, address(PERMIT2))),
                    keccak256(
                        abi.encode(
                            PermitHash._PERMIT_TRANSFER_FROM_TYPEHASH,
                            keccak256(abi.encode(PermitHash._TOKEN_PERMISSIONS_TYPEHASH, _permit.permitted)),
                            address(marketCloned),
                            _permit.nonce,
                            _permit.deadline
                        )
                    )
                )
            )
        );

        return abi.encodePacked(r, s, v);
    }
}
