// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.16;

import "dss-test/DssTest.sol";

import { Ngt } from "../Ngt.sol";
import { MkrNgt } from "../MkrNgt.sol";

contract Mkr is Ngt {}

contract MkrNgtTest is DssTest {
    Mkr     mkr;
    Ngt     ngt;
    MkrNgt  mkrNgt;

    event MkrToNgt(address indexed caller, address indexed usr, uint256 wad);
    event NgtToMkr(address indexed caller, address indexed usr, uint256 wad);

    function setUp() public {
        mkr = new Mkr();
        ngt = new Ngt();
        mkrNgt = new MkrNgt(address(mkr), address(ngt), 1200);
        mkr.mint(address(this), 1_000_000 * WAD);
        mkr.rely(address(mkrNgt));
        mkr.deny(address(this));
        ngt.rely(address(mkrNgt));
        ngt.deny(address(this));
    }

    function testExchange() public {
        assertEq(mkr.balanceOf(address(this)), 1_000_000 * WAD);
        assertEq(mkr.totalSupply(),            1_000_000 * WAD);
        assertEq(ngt.balanceOf(address(this)), 0);
        assertEq(ngt.totalSupply(),            0);

        mkr.approve(address(mkrNgt), 400_000 * WAD);
        vm.expectEmit(true, true, true, true);
        emit MkrToNgt(address(this), address(this), 400_000 * WAD);
        mkrNgt.mkrToNgt(address(this), 400_000 * WAD);
        assertEq(mkr.balanceOf(address(this)), 600_000 * WAD);
        assertEq(mkr.totalSupply(),            600_000 * WAD);
        assertEq(ngt.balanceOf(address(this)), 400_000 * WAD * 1200);
        assertEq(ngt.totalSupply(),            400_000 * WAD * 1200);

        ngt.approve(address(mkrNgt), 200_000 * WAD * 1200);
        vm.expectEmit(true, true, true, true);
        emit NgtToMkr(address(this), address(this), 200_000 * WAD);
        mkrNgt.ngtToMkr(address(this), 200_000 * WAD);
        assertEq(mkr.balanceOf(address(this)), 800_000 * WAD);
        assertEq(mkr.totalSupply(),            800_000 * WAD);
        assertEq(ngt.balanceOf(address(this)), 200_000 * WAD * 1200);
        assertEq(ngt.totalSupply(),            200_000 * WAD * 1200);

        address receiver = address(123);
        assertEq(mkr.balanceOf(receiver),                0);
        assertEq(ngt.balanceOf(receiver),                0);

        mkr.approve(address(mkrNgt), 150_000 * WAD);
        vm.expectEmit(true, true, true, true);
        emit MkrToNgt(address(this), receiver, 150_000 * WAD);
        mkrNgt.mkrToNgt(receiver, 150_000 * WAD);
        assertEq(mkr.balanceOf(address(this)), 650_000 * WAD);
        assertEq(mkr.balanceOf(receiver),                  0);
        assertEq(mkr.totalSupply(),            650_000 * WAD);
        assertEq(ngt.balanceOf(address(this)), 200_000 * WAD * 1200);
        assertEq(ngt.balanceOf(receiver),      150_000 * WAD * 1200);
        assertEq(ngt.totalSupply(),            350_000 * WAD * 1200);

        ngt.approve(address(mkrNgt), 50_000 * WAD * 1200);
        vm.expectEmit(true, true, true, true);
        emit NgtToMkr(address(this), receiver, 50_000 * WAD);
        mkrNgt.ngtToMkr(receiver, 50_000 * WAD);
        assertEq(mkr.balanceOf(address(this)), 650_000 * WAD);
        assertEq(mkr.balanceOf(receiver),       50_000 * WAD);
        assertEq(mkr.totalSupply(),            700_000 * WAD);
        assertEq(ngt.balanceOf(address(this)), 150_000 * WAD * 1200);
        assertEq(ngt.balanceOf(receiver),      150_000 * WAD * 1200);
        assertEq(ngt.totalSupply(),            300_000 * WAD * 1200);
    }
}
