// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {RangePilotToken} from "../src/RangePilotToken.sol";

contract RangePilotTokenTest is Test {
    RangePilotToken internal token;

    address internal owner = address(0xA11CE);
    address internal spender = address(0xB0B);
    address internal recipient = address(0xCAFE);

    function setUp() public {
        vm.prank(owner);
        token = new RangePilotToken();
    }

    function test_MetadataInterface() public view {
        IERC20Metadata metadata = IERC20Metadata(address(token));

        assertEq(metadata.name(), "RangePilot");
        assertEq(metadata.symbol(), "RPT");
        assertEq(metadata.decimals(), 18);
    }

    function test_ERC20Interface() public {
        IERC20 erc20 = IERC20(address(token));
        uint256 amount = 100 ether;

        assertEq(erc20.totalSupply(), token.INITIAL_SUPPLY());
        assertEq(erc20.balanceOf(owner), token.INITIAL_SUPPLY());

        vm.prank(owner);
        assertTrue(erc20.transfer(recipient, amount));
        assertEq(erc20.balanceOf(recipient), amount);

        vm.prank(owner);
        assertTrue(erc20.approve(spender, amount));
        assertEq(erc20.allowance(owner, spender), amount);

        vm.prank(spender);
        assertTrue(erc20.transferFrom(owner, recipient, amount));
        assertEq(erc20.allowance(owner, spender), 0);
        assertEq(erc20.balanceOf(recipient), amount * 2);
    }
}
