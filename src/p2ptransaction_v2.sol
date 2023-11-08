// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:oz-upgrades-from P2PTransaction
contract P2PTransactionV2 is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // custom errors
    error Overflow(uint256 a, uint256 b);
    error Underflow(uint256 a, uint256 b);
    error ZeroAddress(address zeroAddress);
    error ZeroAmount(uint256 amount);
    error InsufficientBalance(uint256 balance, uint256 amount);
    error TransferFailed(address recipient, uint256 amount);

    // State variables
    mapping(address => uint256) private balances;
    address public companyAddress;

    // constants
    uint256 private constant Version = 2;
    uint256 private constant BASIS_POINTS = 10000; // For fee calculations
    uint256 private constant MAX_FEE_PCNT = 20; // 0.2%
    uint256 private constant MID_FEE_PCNT = 15; // 0.15%
    uint256 private constant MIN_FEE_PCNT = 10; // 0.1%

    // Events
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Sent(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 fee
    );

    function initialize(address _companyAddress) public initializer {
        if (_companyAddress == address(0)) {
            revert ZeroAddress(_companyAddress);
        }
        companyAddress = _companyAddress;
    }

    function GetVersion() public pure returns (uint256) {
        return Version;
    }

    // Deposit function. Because it's not interacting with external contracts, it's not marked as nonReentrant.
    // This assumption should be revisited whenever the deposit logic is modified.
    function deposit() external payable {
        if (msg.value == 0) {
            revert ZeroAmount(msg.value);
        }
        unchecked {
            uint256 newBalance = balances[msg.sender] + msg.value;
            if (newBalance < balances[msg.sender]) {
                revert Overflow(balances[msg.sender], msg.value);
            }
            balances[msg.sender] = newBalance;
        }

        emit Deposited(msg.sender, msg.value);
    }

    // Withdraw function
    function withdraw(uint256 amount) external nonReentrant {
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance(balances[msg.sender], amount);
        }
        if (address(this).balance < amount) {
            revert InsufficientBalance(address(this).balance, amount);
        }

        unchecked {
            uint256 newBalance = balances[msg.sender] - amount;
            if (newBalance > balances[msg.sender]) {
                revert Underflow(balances[msg.sender], amount);
            }
            balances[msg.sender] = newBalance;
        }

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert TransferFailed(msg.sender, amount);
        }

        emit Withdrawn(msg.sender, amount);
    }

    // Send function
    function send(address recipient, uint256 amount) external nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(recipient != address(0), "Invalid recipient address");

        uint256 fee = calculateFee(amount);

        unchecked {
            // balances[msg.sender] - amount;
            uint256 newBalance = balances[msg.sender] - amount;
            if (newBalance > balances[msg.sender]) {
                revert Underflow(balances[msg.sender], amount);
            }
            balances[msg.sender] = newBalance;

            // amount - fee
            uint256 amountMinusFee = amount - fee;
            if (amountMinusFee > amount) {
                revert Underflow(amount, fee);
            }

            // balances[recipient] + amountMinusFee;
            newBalance = balances[recipient] + amountMinusFee;
            if (newBalance < balances[recipient]) {
                revert Overflow(balances[recipient], amountMinusFee);
            }
            balances[recipient] = newBalance;

            // balances[companyAddress] + fee;
            newBalance = balances[companyAddress] + fee;
            if (newBalance < balances[companyAddress]) {
                revert Overflow(balances[companyAddress], fee);
            }
            balances[companyAddress] = newBalance;
        }

        emit Sent(msg.sender, recipient, amount, fee);
    }

    // View balance function
    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    // Internal function to calculate fee
    function calculateFee(uint256 amount) private pure returns (uint256) {
        uint256 feeRate;
        if (amount < 1 ether) {
            feeRate = MAX_FEE_PCNT; // 0.2%
        } else if (amount <= 5 ether) {
            feeRate = MID_FEE_PCNT; // 0.15%
        } else {
            feeRate = MIN_FEE_PCNT; // 0.1%
        }

        unchecked {
            uint256 amountTimesFeeRate = amount * feeRate;
            if (amountTimesFeeRate < amount) {
                revert Underflow(amount, feeRate);
            }

            uint256 fee = amountTimesFeeRate / BASIS_POINTS;
            if (fee > amount) {
                revert Overflow(amountTimesFeeRate, BASIS_POINTS);
            }

            return fee;
        }
    }

    // Override the _authorizeUpgrade function to include access control
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
    }
}
