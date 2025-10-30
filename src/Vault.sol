//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    error Vault_RedeemFailed();

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }

    function deposit() external payable {
        uint256 amountToMint = msg.value;

        if (amountToMint == 0) {
            revert("Vault_DepositAmountIsZero");
        }

        i_rebaseToken.mint(msg.sender, amountToMint);

        emit Deposit(msg.sender, amountToMint);
    }

    function redeem(uint256 _amount) external {
        uint256 amountToRedeem = _amount; // Use a new variable to store the actual redeem amount
        if (_amount == type(uint256).max) {
            amountToRedeem = i_rebaseToken.balanceOf(msg.sender);
        }
        i_rebaseToken.burn(msg.sender, _amount);

        (bool success,) = payable(msg.sender).call{value: amountToRedeem}("");

        if (!success) {
            revert Vault_RedeemFailed();
        }

        emit Redeem(msg.sender, _amount);
    }

    receive() external payable {}
}
