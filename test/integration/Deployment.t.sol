// SPDX-FileCopyrightText: © 2023 Dai Foundation <www.daifoundation.org>
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

import { SkyDeploy } from "deploy/SkyDeploy.sol";
import { SkyInit, MkrLike } from "deploy/SkyInit.sol";

import { Sky } from "src/Sky.sol";
import { MkrSky } from "src/MkrSky.sol";

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface MkrAuthorityLike {
    function wards(address) external view returns (uint256);
}

interface GemLike {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external;
    function totalSupply() external view returns (uint256);
}

interface OldMkrSkyLike {
    function mkrToSky(address, uint256) external;
    function skyToMkr(address, uint256) external;
}

contract DeploymentTest is DssTest {
    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    address PAUSE_PROXY;
    address MKR;
    address SKY;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        PAUSE_PROXY = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
        MKR         = ChainlogLike(LOG).getAddress("MCD_GOV");
        SKY         = ChainlogLike(LOG).getAddress("SKY");
    }

    function testReplaceMkrSky() public {
        address mkrSky = SkyDeploy.deployMkrSky(address(this), PAUSE_PROXY, MKR, SKY, 24_000);
        assertEq(address(MkrSky(mkrSky).mkr()), MKR);
        assertEq(address(MkrSky(mkrSky).sky()), SKY);
        assertEq(MkrSky(mkrSky).rate(), 24_000);
        assertEq(MkrSky(mkrSky).wards(address(this)), 0);
        assertEq(MkrSky(mkrSky).wards(PAUSE_PROXY), 1);

        DssInstance memory dss = MCD.loadFromChainlog(LOG);

        address oldMkrSky = ChainlogLike(LOG).getAddress("MKR_SKY");

        assertEq(Sky(SKY).wards(oldMkrSky), 1);
        assertEq(MkrAuthorityLike(MkrLike(MKR).authority()).wards(oldMkrSky), 1);

        vm.startPrank(PAUSE_PROXY);
        SkyInit.updateMkrSky(dss, mkrSky);
        vm.stopPrank();

        assertEq(Sky(SKY).wards(oldMkrSky), 1); // only the mkr=>sky direction is supported in the old migrator
        assertEq(MkrAuthorityLike(MkrLike(MKR).authority()).wards(oldMkrSky), 0);
        assertEq(ChainlogLike(LOG).getAddress("MKR_SKY_LEGACY"), oldMkrSky);
        assertEq(ChainlogLike(LOG).getAddress("MKR_SKY"), mkrSky);
        assertEq(Sky(SKY).balanceOf(mkrSky), GemLike(MKR).totalSupply() * 24_000);
        assertEq(MkrSky(mkrSky).fee(), 0);

        deal(MKR, address(this), 1_000);

        // Test mkrToSky on new converter

        assertEq(GemLike(MKR).balanceOf(address(this)), 1_000);
        assertEq(GemLike(SKY).balanceOf(address(this)), 0);

        GemLike(MKR).approve(mkrSky, 600);
        MkrSky(mkrSky).mkrToSky(address(this), 600);

        assertEq(GemLike(MKR).balanceOf(address(this)), 400);
        assertEq(GemLike(SKY).balanceOf(address(this)), 600 * 24_000);

        // mkrToSky on old converter should still work

        GemLike(MKR).approve(oldMkrSky, 200);
        OldMkrSkyLike(oldMkrSky).mkrToSky(address(this), 200);

        assertEq(GemLike(MKR).balanceOf(address(this)), 200);
        assertEq(GemLike(SKY).balanceOf(address(this)), 800 * 24_000);

        // skyToMkr on old converter should fail

        GemLike(SKY).approve(oldMkrSky, 500 * 24_000);
        vm.expectRevert(bytes(""));
        OldMkrSkyLike(oldMkrSky).skyToMkr(address(this), 500 * 24_000);
    }
}
