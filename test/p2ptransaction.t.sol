// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "lib/forge-std/src/Test.sol";
import "../src/p2ptransaction_v2.sol";
import "../src/p2ptransaction.sol";

contract P2PTransactionTest is Test {
    P2PTransaction p2p;
    address companyAddress;

    function setUp() public {
        companyAddress = address(0x123); // Replace with your actual company address
        p2p = new P2PTransaction();
        p2p.initialize(companyAddress);
    }

    function testSingleDepositUpdatesBalance() public {
        uint256 userInitialBalance = p2p.getBalance(address(this));
        assertEq(userInitialBalance, 0);
        assertEq(address(p2p).balance, 0);

        uint256 depositAmount = 1 ether;

        p2p.deposit{value: depositAmount}();
        uint256 userFinalBalance = p2p.getBalance(address(this));
        assertEq(userFinalBalance, userInitialBalance + depositAmount);

        uint256 contractFinalBal = address(p2p).balance;
        assertEq(contractFinalBal, depositAmount);
        assertEq(contractFinalBal, userFinalBalance);
    }

    function test2UserDepositUpdatesBalance() public {
        // UserA and UserB init
        address userA = makeAddr("A");
        vm.deal(userA, 1 ether);
        address userB = makeAddr("B");
        vm.deal(userB, 0.5 ether);
        uint256 userAInitialBalance = p2p.getBalance(userA);
        uint256 userBInitialBalance = p2p.getBalance(userB);
        assertEq(userAInitialBalance, 0);
        assertEq(userBInitialBalance, 0);
        assertEq(address(p2p).balance, 0);

        // UserA deposits
        vm.startPrank(userA); // Pretend to be userA
        p2p.deposit{value: 1 ether}();
        uint256 userAFinalBalance = p2p.getBalance(userA);
        assertEq(userAFinalBalance, userAInitialBalance + 1 ether);

        // Total contract balance should be the same as userA's balance
        uint256 contractBal = address(p2p).balance;
        assertEq(contractBal, 1 ether);
        assertEq(contractBal, userAFinalBalance);

        // UserB deposits
        vm.startPrank(userB); // Pretend to be userB
        p2p.deposit{value: 0.5 ether}();
        uint256 userBFinalBalance = p2p.getBalance(userB);
        assertEq(userBFinalBalance, userBInitialBalance + 0.5 ether);

        // Total contract balance should be the sum of the two deposits
        contractBal = address(p2p).balance;
        assertEq(contractBal, userAFinalBalance + userBFinalBalance);
    }

    function testWithdrawUpdatesBalanceAndTransfersETH() public {
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 0.5 ether;

        p2p.deposit{value: depositAmount}();

        // Check initial balances
        uint256 initialContractBalance = address(p2p).balance;
        assertEq(initialContractBalance, depositAmount);
        uint256 initialUserBalance = p2p.getBalance(address(this));
        assertEq(initialUserBalance, initialContractBalance);

        // Withdraw
        p2p.withdraw(withdrawAmount);

        // Check final balances
        uint256 finalContractBalance = address(p2p).balance;
        uint256 finalUserBalance = p2p.getBalance(address(this));
        assertEq(finalContractBalance, initialContractBalance - withdrawAmount);
        assertEq(finalUserBalance, initialUserBalance - withdrawAmount);
    }

    function testP2PSend() public {
        address recipient = address(0x456);
        uint256 depositAmount = 1 ether;
        uint256 sendAmount = 0.5 ether;

        p2p.deposit{value: depositAmount}();

        uint256 initialSenderBalance = p2p.getBalance(address(this));
        assertEq(initialSenderBalance, depositAmount);
        uint256 initialRecipientBalance = p2p.getBalance(recipient);
        assertEq(initialRecipientBalance, 0);
        uint256 initialCompanyBalance = p2p.getBalance(companyAddress);
        assertEq(initialCompanyBalance, 0);

        p2p.send(recipient, sendAmount);

        uint256 fee = (sendAmount * 20) / 10000; // 0.1% fee rate in basis points
        uint256 finalSenderBalance = p2p.getBalance(address(this));
        uint256 finalRecipientBalance = p2p.getBalance(recipient);
        uint256 finalCompanyBalance = p2p.getBalance(companyAddress);

        assertEq(finalSenderBalance, initialSenderBalance - sendAmount);
        assertEq(
            finalRecipientBalance,
            initialRecipientBalance + sendAmount - fee
        );
        assertEq(finalCompanyBalance, initialCompanyBalance + fee);
    }

    // receive Ether
    receive() external payable {}
}
