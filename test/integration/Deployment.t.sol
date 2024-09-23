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

import { SkyInstance } from "deploy/SkyInstance.sol";
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
}

contract DeploymentTest is DssTest {
    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    address PAUSE_PROXY;
    address MKR;

    SkyInstance inst;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        PAUSE_PROXY = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
        MKR         = ChainlogLike(LOG).getAddress("MCD_GOV");

        inst = SkyDeploy.deploy(address(this), PAUSE_PROXY, MKR, 1200);
    }

    function testSetUp() public {
        DssInstance memory dss = MCD.loadFromChainlog(LOG);

        assertEq(Sky(inst.sky).wards(inst.mkrSky), 0);
        assertEq(MkrAuthorityLike(MkrLike(MKR).authority()).wards(inst.mkrSky), 0);

        vm.startPrank(PAUSE_PROXY);
        SkyInit.init(dss, inst, 1200);
        vm.stopPrank();

        assertEq(Sky(inst.sky).wards(inst.mkrSky), 1);
        assertEq(MkrAuthorityLike(MkrLike(MKR).authority()).wards(inst.mkrSky), 1);

        deal(MKR, address(this), 1000);

        assertEq(GemLike(MKR).balanceOf(address(this)), 1000);
        assertEq(GemLike(inst.sky).balanceOf(address(this)), 0);

        GemLike(MKR).approve(inst.mkrSky, 600);
        MkrSky(inst.mkrSky).mkrToSky(address(this), 600);

        assertEq(GemLike(MKR).balanceOf(address(this)), 400);
        assertEq(GemLike(inst.sky).balanceOf(address(this)), 600 * 1200);

        GemLike(inst.sky).approve(inst.mkrSky, 400 * 1200);
        MkrSky(inst.mkrSky).skyToMkr(address(this), 400 * 1200);

        assertEq(GemLike(MKR).balanceOf(address(this)), 800);
        assertEq(GemLike(inst.sky).balanceOf(address(this)), 200 * 1200);

        assertEq(ChainlogLike(LOG).getAddress("SKY"), inst.sky);
        assertEq(ChainlogLike(LOG).getAddress("MKR_SKY"), inst.mkrSky);
    }
}
