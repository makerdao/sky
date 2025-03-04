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

    uint256 rate = 24_000;

    event Collect(address indexed to, uint256 take);
    event Burn(uint256 skyAmt);
    event MkrToSky(address indexed caller, address indexed usr, uint256 mkrAmt, uint256 skyAmt, uint256 skyFee);

    function setUp() public {
        mkr = new Mkr();
        sky = new Sky();
        mkrSky = new MkrSky(address(mkr), address(sky), rate);
        mkr.mint(address(this), 1_000_000 * WAD);
        sky.mint(address(mkrSky), 1_000_000 * WAD * rate);
        mkrSky.file("fee", 0.01 ether);
    }

    function testAuth() public {
        checkAuth(address(mkrSky), "MkrSky");
    }

    function testFile() public {
        checkFileUint(address(mkrSky), "MkrSky", ["fee"]);

        vm.expectRevert("MkrSky/fee-exceeds-wad");
        mkrSky.file("fee", WAD + 1);
    }

    function testModifiers() public {
        bytes4[] memory authedMethods = new bytes4[](2);
        authedMethods[0] = mkrSky.collect.selector;
        authedMethods[1] = mkrSky.burn.selector;

        // this checks the case where sender is not authed
        vm.startPrank(address(0xBEEF));
        checkModifier(address(mkrSky), "MkrSky/not-authorized", authedMethods);
        vm.stopPrank();
    }

    function testCollect() public {
        mkr.approve(address(mkrSky), 100_000 * WAD);
        mkrSky.mkrToSky(address(this), 100_000 * WAD);
        assertEq(mkrSky.take(), 1_000 * WAD * rate);

        vm.expectEmit(true, true, true, true);
        emit Collect(address(0xfee), 1_000 * WAD * rate);
        mkrSky.collect(address(0xfee));

        assertEq(mkrSky.take(), 0);
        assertEq(sky.balanceOf(address(0xfee)), 1_000 * WAD * rate);
        vm.expectRevert("MkrSky/nothing-to-collect");
        mkrSky.collect(address(0xfee));
    }

    function testBurn() public {
        assertEq(sky.balanceOf(address(mkrSky)), 1_000_000 * WAD * rate);
        assertEq(sky.totalSupply(),              1_000_000 * WAD * rate);

        vm.expectEmit();
        emit Burn(400_000 * WAD * rate);
        mkrSky.burn(400_000 * WAD * rate);

        assertEq(sky.balanceOf(address(mkrSky)), 600_000 * WAD * rate);
        assertEq(sky.totalSupply(),              600_000 * WAD * rate);

        vm.expectEmit();
        emit Burn(600_000 * WAD * rate);
        mkrSky.burn(600_000 * WAD * rate);

        assertEq(sky.balanceOf(address(mkrSky)), 0);
        assertEq(sky.totalSupply(),              0);
    }

    function testExchange() public {
        assertEq(mkr.balanceOf(address(this)),   1_000_000 * WAD);
        assertEq(mkr.totalSupply(),              1_000_000 * WAD);
        assertEq(sky.balanceOf(address(this)),   0);
        assertEq(sky.balanceOf(address(mkrSky)), 1_000_000 * WAD * rate);
        assertEq(sky.totalSupply(),              1_000_000 * WAD * rate);

        mkr.approve(address(mkrSky), 400_000 * WAD);

        vm.expectEmit(true, true, true, true);
        emit MkrToSky(address(this), address(this), 400_000 * WAD,  (400_000 - 4_000) * WAD * rate, 4_000 * WAD * rate);
        mkrSky.mkrToSky(address(this), 400_000 * WAD);
        assertEq(mkr.balanceOf(address(this)),   600_000 * WAD);
        assertEq(mkr.totalSupply(),              600_000 * WAD);
        assertEq(sky.balanceOf(address(this)),   396_000 * WAD * rate);
        assertEq(sky.balanceOf(address(mkrSky)), 604_000 * WAD * rate);
        assertEq(sky.totalSupply(),              1_000_000 * WAD * rate);
        assertEq(mkrSky.take(),                  4_000 * WAD * rate);

        mkr.approve(address(mkrSky), 400_000 * WAD);

        vm.expectEmit(true, true, true, true);
        emit MkrToSky(address(this), address(123), 400_000 * WAD,  (400_000 - 4_000) * WAD * rate, 4_000 * WAD * rate);
        mkrSky.mkrToSky(address(123), 400_000 * WAD);
        assertEq(mkr.balanceOf(address(this)),   200_000 * WAD);
        assertEq(mkr.totalSupply(),              200_000 * WAD);
        assertEq(sky.balanceOf(address(123)),    396_000 * WAD * rate);
        assertEq(sky.balanceOf(address(mkrSky)), 208_000 * WAD * rate);
        assertEq(sky.totalSupply(),              1_000_000 * WAD * rate);
        assertEq(mkrSky.take(),                  8_000 * WAD * rate);
    }
}
