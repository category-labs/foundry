// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.20;

import {Test} from "forge-std/Test.sol";

interface IReserveBalance {
    function dippedIntoReserve() external returns (bool);
}

contract RefundSink {
    receive() external payable {}

    function refund(address payable recipient, uint256 amount) external {
        (bool success,) = recipient.call{value: amount}("");
        require(success, "refund failed");
    }
}

contract DelegatedReserveProbe {
    IReserveBalance internal constant RESERVE = IReserveBalance(address(0x1001));

    receive() external payable {}

    function dipWithoutRestore(RefundSink sink, uint256 amount)
        external
        returns (bool beforeDip, bool duringDip, uint256 beforeBalance, uint256 duringBalance)
    {
        beforeBalance = address(this).balance;
        beforeDip = RESERVE.dippedIntoReserve();

        (bool success,) = address(sink).call{value: amount}("");
        require(success, "dip failed");

        duringBalance = address(this).balance;
        duringDip = RESERVE.dippedIntoReserve();
    }

    function dipAndRestore(RefundSink sink, uint256 amount)
        external
        returns (
            bool beforeDip,
            bool duringDip,
            bool afterRestore,
            uint256 beforeBalance,
            uint256 duringBalance,
            uint256 afterBalance
        )
    {
        beforeBalance = address(this).balance;
        beforeDip = RESERVE.dippedIntoReserve();

        (bool success,) = address(sink).call{value: amount}("");
        require(success, "dip failed");

        duringBalance = address(this).balance;
        duringDip = RESERVE.dippedIntoReserve();

        // Restore through a real call rather than mutating the balance with a cheatcode.
        sink.refund(payable(address(this)), amount);

        afterBalance = address(this).balance;
        afterRestore = RESERVE.dippedIntoReserve();
    }
}

/// Forge regression for MIP-4 reserve tracking through a cheatcode-delegated EOA.
contract MonadReserveBalanceTest is Test {
    uint256 internal constant AUTHORITY_PRIVATE_KEY = 0xA11CE;

    address payable internal authority;
    address internal caller;

    DelegatedReserveProbe internal implementation;
    RefundSink internal sink;

    function setUp() public {
        authority = payable(vm.addr(AUTHORITY_PRIVATE_KEY));
        caller = makeAddr("caller");

        implementation = new DelegatedReserveProbe();
        sink = new RefundSink();

        // Establish the authority's balance and delegation before the isolated
        // test transaction begins. These are preconditions, not measured changes.
        vm.deal(authority, 11 ether);
        vm.signAndAttachDelegation(address(implementation), AUTHORITY_PRIVATE_KEY);

        // Confirm that the authority contains the expected EIP-7702 delegation indicator.
        bytes memory code = authority.code;
        bytes memory expectedCode = abi.encodePacked(hex"ef0100", address(implementation));

        assertEq(code.length, 23, "invalid delegation indicator length");
        assertEq(code, expectedCode, "authority should delegate to implementation");
    }

    function test_reserveTrackerActivatesAfterDelegatedAccountDip() public {
        vm.prank(caller);

        (bool beforeDip, bool duringDip, uint256 beforeBalance, uint256 duringBalance) =
            DelegatedReserveProbe(authority).dipWithoutRestore(sink, 2 ether);

        assertEq(beforeBalance, 11 ether, "unexpected starting balance");
        assertEq(duringBalance, 9 ether, "unexpected dipped balance");
        assertEq(authority.balance, 9 ether, "authority should remain dipped");

        assertFalse(beforeDip, "reserve tracker should start clear");
        assertTrue(duringDip, "reserve tracker should activate after dip");

        // `isolate = true` runs the delegated call as its own synthetic transaction.
        // Restore the fixture balance afterward; this regression covers tracker
        // transitions, not end-of-transaction reserve enforcement.
        sink.refund(authority, 2 ether);

        assertEq(authority.balance, 11 ether, "authority should be restored");
    }

    function test_reserveTrackerClearsAfterDelegatedAccountRestore() public {
        vm.prank(caller);

        (
            bool beforeDip,
            bool duringDip,
            bool afterRestore,
            uint256 beforeBalance,
            uint256 duringBalance,
            uint256 afterBalance
        ) = DelegatedReserveProbe(authority).dipAndRestore(sink, 2 ether);

        assertEq(beforeBalance, 11 ether, "unexpected starting balance");
        assertEq(duringBalance, 9 ether, "unexpected dipped balance");
        assertEq(afterBalance, 11 ether, "unexpected restored balance");
        assertEq(authority.balance, 11 ether, "authority should end restored");
        assertEq(address(sink).balance, 0, "sink should return the temporary debit");

        assertFalse(beforeDip, "reserve tracker should start clear");
        assertTrue(duringDip, "reserve tracker should activate after dip");
        assertFalse(afterRestore, "reserve tracker should clear inside the delegated call");
    }
}
