//SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");

    function setUp() public {
        vm.startPrank(owner);

        rebaseToken = new RebaseToken();

        vault = new Vault(IRebaseToken(address(rebaseToken)));

        rebaseToken.grantMintAndBurnRole(address(vault));

        (bool success,) = payable(address(vault)).call{value: 1 ether}("");
        console.log("It ", success);

        vm.stopPrank();
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);

        vault.deposit{value: amount}();

        uint256 initialBalance = rebaseToken.balanceOf(user);

        uint256 timeDelta = 1 days;
        vm.warp(block.timestamp + timeDelta);

        uint256 balanceAfterFirstWarp = rebaseToken.balanceOf(user);

        uint256 interestFirstPeriod = balanceAfterFirstWarp - initialBalance;

        vm.warp(block.timestamp + timeDelta);

        uint256 balanceAfterSecondWarp = rebaseToken.balanceOf(user);

        uint256 interestSecondPeriod = balanceAfterSecondWarp - balanceAfterFirstWarp;

        assertApproxEqAbs(interestFirstPeriod, interestSecondPeriod, 2, "Interest Accrual Is not linear");

        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.startPrank(user);
        vm.deal(user, amount);

        vault.deposit{value: amount}();

        vault.redeem(type(uint256).max);

        uint256 userBalance = rebaseToken.balanceOf(user);

        assertEq(userBalance, 0, "Balance didnt got zero after redeem");

        vm.stopPrank();
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5, type(uint96).max);
        uint256 amountToSend = amount / 2;
        vm.startPrank(user);
        vm.deal(user, amount);

        vault.deposit{value: amount}();

        vm.stopPrank();

        vm.startPrank(owner);
        rebaseToken.setInterestRate(4e10);
        vm.stopPrank();

        vm.startPrank(user);
        rebaseToken.transfer(user2, amountToSend);

        vm.stopPrank();

        assertEq(rebaseToken.getUserInterestRate(user), rebaseToken.getUserInterestRate(user2));
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);

        vault.deposit{value: amount}();

        assertEq(rebaseToken.principleBalanceOf(user), amount);

        vm.warp(2 days);

        assertEq(rebaseToken.principleBalanceOf(user), amount);

        vm.stopPrank();
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.startPrank(user2);
        vm.expectRevert();
        rebaseToken.setInterestRate(4e10);
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
        // vm.assume(success); // Optionally, assume the transfer succeeds
    }
}
