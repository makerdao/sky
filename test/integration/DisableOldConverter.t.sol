// SPDX-FileCopyrightText: © 2025 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.21;

import "dss-test/DssTest.sol";

import { SkyInit } from "deploy/SkyInit.sol";
import { Sky } from "src/Sky.sol";
import { MkrSky } from "src/MkrSky.sol";

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface GemLike {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external;
    function totalSupply() external view returns (uint256);
}

contract DeploymentTest is DssTest {
    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    address PAUSE_PROXY;
    address MKR;
    address SKY;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        PAUSE_PROXY = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
        MKR         = ChainlogLike(LOG).getAddress("MKR");
        SKY         = ChainlogLike(LOG).getAddress("MCD_GOV");
    }

    function testDisableOldConverterMkrSky() public {
        DssInstance memory dss = MCD.loadFromChainlog(LOG);

        address oldMkrSky = ChainlogLike(LOG).getAddress("MKR_SKY_LEGACY"); // does not revert
        assertEq(Sky(SKY).wards(oldMkrSky), 1);

        // can convert MKR=>SKY before disabling old converter
        deal(MKR, address(this), 1_000);
        assertEq(GemLike(MKR).balanceOf(address(this)), 1_000);
        assertEq(GemLike(SKY).balanceOf(address(this)), 0);
        GemLike(MKR).approve(oldMkrSky, 1_000);
        MkrSky(oldMkrSky).mkrToSky(address(this), 1_000);
        assertEq(GemLike(MKR).balanceOf(address(this)), 0);
        assertEq(GemLike(SKY).balanceOf(address(this)), 1_000 * 24_000);

        vm.startPrank(PAUSE_PROXY);
        SkyInit.disableOldConverterMkrSky(dss);
        vm.stopPrank();

        vm.expectRevert("dss-chain-log/invalid-key");
        ChainlogLike(LOG).getAddress("MKR_SKY_LEGACY");
        assertEq(Sky(SKY).wards(oldMkrSky), 0);

        // can not convert MKR=>SKY after disabling old converter
        deal(MKR, address(this), 1_000);
        assertEq(GemLike(MKR).balanceOf(address(this)), 1_000);
        assertEq(GemLike(SKY).balanceOf(address(this)), 1_000 * 24_000);
        GemLike(MKR).approve(oldMkrSky, 1_000);
        vm.expectRevert("Sky/not-authorized");
        MkrSky(oldMkrSky).mkrToSky(address(this), 1_000);
    }

    function testBurnExtraSky() public {
        DssInstance memory dss = MCD.loadFromChainlog(LOG);
        address mkrSky = ChainlogLike(LOG).getAddress("MKR_SKY");

        assertGt(GemLike(SKY).balanceOf(mkrSky), GemLike(MKR).totalSupply() * 24_000);

        vm.startPrank(PAUSE_PROXY);
        SkyInit.burnExtraSky(dss);
        vm.stopPrank();

        assertEq(GemLike(SKY).balanceOf(mkrSky), GemLike(MKR).totalSupply() * 24_000);
    }
}
