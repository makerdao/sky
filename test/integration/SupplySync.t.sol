// SPDX-FileCopyrightText: © 2024 Dai Foundation <www.daifoundation.org>
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
import { SupplySync } from "src/SupplySync.sol";
import { SkyDeploy } from "deploy/SkyDeploy.sol";
import { SkyInit } from "deploy/SkyInit.sol";

interface GemLike {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function burn(address, uint256) external;
}

interface SkyLike is GemLike {
    function wards(address) external view returns (uint256);
    function deny(address) external;
}

contract SupplySyncTest is DssTest {
    DssInstance dss;

    address    PAUSE_PROXY;
    GemLike    MKR;
    SkyLike    SKY;

    SupplySync sync;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        dss = MCD.loadFromChainlog(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

        PAUSE_PROXY = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
        MKR         = GemLike(dss.chainlog.getAddress("MCD_GOV"));
        SKY         = SkyLike(dss.chainlog.getAddress("SKY"));

        sync = SupplySync(SkyDeploy.deploySupplySync(dss.chainlog.getAddress("MKR_SKY"), PAUSE_PROXY));
        vm.startPrank(PAUSE_PROXY);
        SkyInit.initSupplySync(dss, address(sync));
        vm.stopPrank();
    }

    function testDeployAndInit() public {
        assertEq(address(sync.mkr()), address(MKR));
        assertEq(address(sync.sky()), address(SKY));
        assertEq(sync.rate(), 24_000);
        assertEq(SKY.allowance(address(sync), PAUSE_PROXY), type(uint256).max);
        assertEq(SKY.wards(address(sync)), 1);
        assertEq(dss.chainlog.getAddress("SKY_SUPPLY_SYNC"), address(sync));
    }

    function _checkSync(bool isExpectedMint, uint256 expectedChange) internal {
        uint256 mkrSupply         = MKR.totalSupply();
        uint256 skySupplyBefore   = SKY.totalSupply();
        uint256 syncBalanceBefore = SKY.balanceOf(address(sync));

        (bool isMint, uint256 amount) = sync.sync();

        uint256 syncBalanceAfter = SKY.balanceOf(address(sync));

        assertEq(syncBalanceAfter, mkrSupply * 24_000);
        assertEq(isMint, isExpectedMint);
        assertEq(amount, expectedChange);
        if (isExpectedMint) {
            assertEq(syncBalanceAfter,  syncBalanceBefore + expectedChange);
            assertEq(SKY.totalSupply(), skySupplyBefore   + expectedChange);
        } else {
            assertEq(syncBalanceAfter,  syncBalanceBefore - expectedChange);
            assertEq(SKY.totalSupply(), skySupplyBefore   - expectedChange);
        }
    }

    function testZeroSkyInSync() public {
        deal(address(SKY), address(sync), 0);
        _checkSync(true, MKR.totalSupply() * 24_000);
    }

    function testLessSkyInSync() public {
        deal(address(SKY), address(sync), MKR.totalSupply() * 24_000 - 1234);
        _checkSync(true, 1234);
    }

    function testMoreSkyInSync() public {
        deal(address(SKY), address(sync), MKR.totalSupply() * 24_000 + 1234);
        _checkSync(false, 1234);
    }

    function testExactSkyInSync() public {
        deal(address(SKY), address(sync), MKR.totalSupply() * 24_000);
        _checkSync(false, 0);
    }

    function testWindDown() public {
        deal(address(SKY), address(sync), 1234);

        vm.startPrank(PAUSE_PROXY);
        SKY.burn(address(sync), SKY.balanceOf(address(sync)));
        SKY.deny(address(sync)); // revoke mint allowance
        vm.stopPrank();

        assertEq(SKY.balanceOf(address(sync)), 0);
        vm.expectRevert("Sky/not-authorized");
        sync.sync();
    }
}
