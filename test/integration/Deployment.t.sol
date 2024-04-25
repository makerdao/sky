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

import { NgtInstance } from "deploy/NgtInstance.sol";
import { NgtDeploy } from "deploy/NgtDeploy.sol";
import { NgtInit, MkrLike } from "deploy/NgtInit.sol";

import { Ngt } from "src/Ngt.sol";
import { MkrNgt } from "src/MkrNgt.sol";

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

    NgtInstance inst;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        PAUSE_PROXY = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
        MKR         = ChainlogLike(LOG).getAddress("MCD_GOV");

        inst = NgtDeploy.deploy(address(this), PAUSE_PROXY, MKR, 1200);
    }

    function testSetUp() public {
        DssInstance memory dss = MCD.loadFromChainlog(LOG);

        assertEq(Ngt(inst.ngt).wards(inst.mkrNgt), 0);
        assertEq(MkrAuthorityLike(MkrLike(MKR).authority()).wards(inst.mkrNgt), 0);

        vm.startPrank(PAUSE_PROXY);
        NgtInit.init(dss, inst, 1200);
        vm.stopPrank();

        assertEq(Ngt(inst.ngt).wards(inst.mkrNgt), 1);
        assertEq(MkrAuthorityLike(MkrLike(MKR).authority()).wards(inst.mkrNgt), 1);

        deal(MKR, address(this), 1000);

        assertEq(GemLike(MKR).balanceOf(address(this)), 1000);
        assertEq(GemLike(inst.ngt).balanceOf(address(this)), 0);

        GemLike(MKR).approve(inst.mkrNgt, 600);
        MkrNgt(inst.mkrNgt).mkrToNgt(address(this), 600);

        assertEq(GemLike(MKR).balanceOf(address(this)), 400);
        assertEq(GemLike(inst.ngt).balanceOf(address(this)), 600 * 1200);

        GemLike(inst.ngt).approve(inst.mkrNgt, 400 * 1200);
        MkrNgt(inst.mkrNgt).ngtToMkr(address(this), 400 * 1200);

        assertEq(GemLike(MKR).balanceOf(address(this)), 800);
        assertEq(GemLike(inst.ngt).balanceOf(address(this)), 200 * 1200);

        assertEq(ChainlogLike(LOG).getAddress("NGT"), inst.ngt);
        assertEq(ChainlogLike(LOG).getAddress("MKR_NGT"), inst.mkrNgt);
    }
}
