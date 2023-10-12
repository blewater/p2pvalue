// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract P2PTransaction is ReentrancyGuard {
    using SafeMath for uint256;

    // State variables
    mapping(address => uint256) private balances;
    address public companyAddress;
    uint256 private constant BASIS_POINTS = 10000; // For fee calculations

    // Events
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Sent(address indexed from, address indexed to, uint256 amount, uint256 fee);

    // Constructor
    constructor(address _companyAddress) {
        require(_companyAddress != address(0), "Invalid company address");
        companyAddress = _companyAddress;
    }

    // Deposit function
    function deposit() external payable nonReentrant {
        require(msg.value > 0, "Deposit amount must be greater than zero");
        balances[msg.sender] = balances[msg.sender].add(msg.value);
        emit Deposited(msg.sender, msg.value);
    }

    // Withdraw function
    function withdraw(uint256 amount) external nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] = balances[msg.sender].sub(amount);
        payable(msg.sender).transfer(amount);
        emit Withdrawn(msg.sender, amount);
    }

    // Send function
    function send(address recipient, uint256 amount) external nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(recipient != address(0), "Invalid recipient address");

        uint256 fee = calculateFee(amount);
        balances[msg.sender] = balances[msg.sender].sub(amount);
        balances[recipient] = balances[recipient].add(amount.sub(fee));
        balances[companyAddress] = balances[companyAddress].add(fee);

        emit Sent(msg.sender, recipient, amount, fee);
    }

    // View balance function
    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    // Internal function to calculate fee
    function calculateFee(uint256 amount) internal pure returns (uint256) {
        uint256 feeRate;
        if (amount < 1 ether) {
            feeRate = 20; // 0.2%
        } else if (amount >= 1 ether && amount <= 5 ether) {
            feeRate = 15; // 0.15%
        } else {
            feeRate = 10; // 0.1%
        }
        return amount.mul(feeRate).div(BASIS_POINTS);
    }
}
