// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import "dss-test/DssTest.sol";

import { Sky } from "src/Sky.sol";
import { MkrSky } from "src/MkrSky.sol";

contract Mkr is Sky {}

contract MkrSkyTest is DssTest {
    Mkr     mkr;
    Sky     sky;
    MkrSky  mkrSky;

    event MkrToSky(address indexed caller, address indexed usr, uint256 mkrAmt, uint256 skyAmt);
    event SkyToMkr(address indexed caller, address indexed usr, uint256 skyAmt, uint256 mkrAmt);

    function setUp() public {
        mkr = new Mkr();
        sky = new Sky();
        mkrSky = new MkrSky(address(mkr), address(sky), 1200);
        mkr.mint(address(this), 1_000_000 * WAD);
        mkr.rely(address(mkrSky));
        mkr.deny(address(this));
        sky.rely(address(mkrSky));
        sky.deny(address(this));
    }

    function testExchange() public {
        assertEq(mkr.balanceOf(address(this)), 1_000_000 * WAD);
        assertEq(mkr.totalSupply(),            1_000_000 * WAD);
        assertEq(sky.balanceOf(address(this)), 0);
        assertEq(sky.totalSupply(),            0);

        mkr.approve(address(mkrSky), 400_000 * WAD);
        vm.expectEmit(true, true, true, true);
        emit MkrToSky(address(this), address(this), 400_000 * WAD,  400_000 * WAD * 1200);
        mkrSky.mkrToSky(address(this), 400_000 * WAD);
        assertEq(mkr.balanceOf(address(this)), 600_000 * WAD);
        assertEq(mkr.totalSupply(),            600_000 * WAD);
        assertEq(sky.balanceOf(address(this)), 400_000 * WAD * 1200);
        assertEq(sky.totalSupply(),            400_000 * WAD * 1200);

        sky.approve(address(mkrSky), 200_000 * WAD * 1200);
        vm.expectEmit(true, true, true, true);
        emit SkyToMkr(address(this), address(this), 200_000 * WAD * 1200, 200_000 * WAD);
        mkrSky.skyToMkr(address(this), 200_000 * WAD * 1200);
        assertEq(mkr.balanceOf(address(this)), 800_000 * WAD);
        assertEq(mkr.totalSupply(),            800_000 * WAD);
        assertEq(sky.balanceOf(address(this)), 200_000 * WAD * 1200);
        assertEq(sky.totalSupply(),            200_000 * WAD * 1200);

        address receiver = address(123);
        assertEq(mkr.balanceOf(receiver),                0);
        assertEq(sky.balanceOf(receiver),                0);

        mkr.approve(address(mkrSky), 150_000 * WAD);
        vm.expectEmit(true, true, true, true);
        emit MkrToSky(address(this), receiver, 150_000 * WAD, 150_000 * WAD * 1200);
        mkrSky.mkrToSky(receiver, 150_000 * WAD);
        assertEq(mkr.balanceOf(address(this)), 650_000 * WAD);
        assertEq(mkr.balanceOf(receiver),                  0);
        assertEq(mkr.totalSupply(),            650_000 * WAD);
        assertEq(sky.balanceOf(address(this)), 200_000 * WAD * 1200);
        assertEq(sky.balanceOf(receiver),      150_000 * WAD * 1200);
        assertEq(sky.totalSupply(),            350_000 * WAD * 1200);

        sky.approve(address(mkrSky), 50_000 * WAD * 1200);
        vm.expectEmit(true, true, true, true);
        emit SkyToMkr(address(this), receiver, 50_000 * WAD * 1200, 50_000 * WAD);
        mkrSky.skyToMkr(receiver, 50_000 * WAD * 1200);
        assertEq(mkr.balanceOf(address(this)), 650_000 * WAD);
        assertEq(mkr.balanceOf(receiver),       50_000 * WAD);
        assertEq(mkr.totalSupply(),            700_000 * WAD);
        assertEq(sky.balanceOf(address(this)), 150_000 * WAD * 1200);
        assertEq(sky.balanceOf(receiver),      150_000 * WAD * 1200);
        assertEq(sky.totalSupply(),            300_000 * WAD * 1200);

        sky.approve(address(mkrSky), 50_000 * WAD * 1200 + 1199);
        vm.expectEmit(true, true, true, true);
        emit SkyToMkr(address(this), address(this), 50_000 * WAD * 1200 + 1199, 50_000 * WAD);
        mkrSky.skyToMkr(address(this), 50_000 * WAD * 1200 + 1199);
        assertEq(mkr.balanceOf(address(this)), 700_000 * WAD);
        assertEq(mkr.balanceOf(receiver),       50_000 * WAD);
        assertEq(mkr.totalSupply(),            750_000 * WAD);
        assertEq(sky.balanceOf(address(this)), 100_000 * WAD * 1200 - 1199);
        assertEq(sky.balanceOf(receiver),      150_000 * WAD * 1200);
        assertEq(sky.totalSupply(),            250_000 * WAD * 1200 - 1199);
    }
}
