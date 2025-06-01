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

import { SkyDeploy } from "deploy/SkyDeploy.sol";

import { Sky } from "src/Sky.sol";

contract DeploymentTest is DssTest {

    address l2GovRelay = address(222);
    address sky;

    function setUp() public {
        sky = SkyDeploy.deployL2(address(this), l2GovRelay);
    }

    function testSetUp() public view {
        assertEq(Sky(sky).wards(l2GovRelay), 1);
        assertEq(Sky(sky).wards(address(this)), 0);
    }
}
