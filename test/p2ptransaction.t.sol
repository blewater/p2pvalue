// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/Test.sol";
// import "forge-vm/VM.sol";
import {P2PTransaction} from "../src/p2ptransaction.sol";

contract P2PTransactionTest is Test {
    P2PTransaction p2p;
    address companyAddress;

    function setUp() public {
        companyAddress = address(0x123);  // Replace with your actual company address
        p2p = new P2PTransaction(companyAddress);
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
        address userA = address(0x456);
        address userB = address(0x789);
        uint256 userAInitialBalance = p2p.getBalance(userA);
        uint256 userBInitialBalance = p2p.getBalance(userB);
        assertEq(userAInitialBalance, 0);
        assertEq(userBInitialBalance, 0);
        assertEq(address(p2p).balance, 0);

        vm.prank(userA);  // Pretend to be userA
        p2p.deposit{value: 1 ether}();
        uint256 userAFinalBalance = p2p.getBalance(address(this));
        assertEq(userAFinalBalance, userAInitialBalance + 1 ether);
        uint256 contractBal = address(p2p).balance;
        assertEq(contractBal, 1 ether);
        assertEq(contractBal, userAFinalBalance);

        vm.prank(userB); // Pretend to be userB
        deal(userB, 0.5);
        p2p.deposit{value: 0.5 ether}();
        uint256 userBFinalBalance = p2p.getBalance(address(this));
        assertEq(userBFinalBalance, userBInitialBalance + 0.5 ether);
        contractBal = address(p2p).balance;
        assertEq(contractBal, userAFinalBalance + userBFinalBalance);
    }

    function testWithdrawUpdatesBalanceAndTransfersETH() public {
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 0.5 ether;

        p2p.deposit{value: depositAmount}();

        uint256 initialContractBalance = address(p2p).balance;
        uint256 initialUserBalance = p2p.getBalance(address(this));

        p2p.withdraw(withdrawAmount);

        uint256 finalContractBalance = address(p2p).balance;
        uint256 finalUserBalance = p2p.getBalance(address(this));

        assertEq(finalContractBalance, initialContractBalance - withdrawAmount);
        assertEq(finalUserBalance, initialUserBalance - withdrawAmount);
    }

    function testP2PTransactionUpdatesgetBalancesAndDeductsFe() public {
        address recipient = address(0x456);  // Replace with your actual recipient address
        uint256 depositAmount = 1 ether;
        uint256 sendAmount = 0.5 ether;

        p2p.deposit{value: depositAmount}();

        uint256 initialSenderBalance = p2p.getBalance(address(this));
        uint256 initialRecipientBalance = p2p.getBalance(recipient);
        uint256 initialCompanyBalance = p2p.getBalance(companyAddress);

        p2p.send(recipient, sendAmount);

        uint256 fee = sendAmount * 10 / 10000;  // 0.1% fee rate in basis points
        uint256 finalSenderBalance = p2p.getBalance(address(this));
        uint256 finalRecipientBalance = p2p.getBalance(recipient);
        uint256 finalCompanyBalance = p2p.getBalance(companyAddress);

        assertEq(finalSenderBalance, initialSenderBalance - sendAmount);
        assertEq(finalRecipientBalance, initialRecipientBalance + sendAmount - fee);
        assertEq(finalCompanyBalance, initialCompanyBalance + fee);
    }
}