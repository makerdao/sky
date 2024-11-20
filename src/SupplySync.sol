// SPDX-License-Identifier: AGPL-3.0-or-later

/// MkrSky.sol -- Mkr/Sky Exchanger

// Copyright (C) 2024 Dai Foundation
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

interface GemLike {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external;
    function mint(address, uint256) external;
    function burn(address, uint256) external;
}

interface MkrSkyLike {
    function mkr() external view returns (address);
    function sky() external view returns (address);
    function rate() external view returns (uint256);
}

contract SupplySync {
    GemLike public immutable mkr;
    GemLike public immutable sky;
    uint256 public immutable rate;

    constructor(address mkrSky, address owner) {
        mkr  = GemLike(MkrSkyLike(mkrSky).mkr());
        sky  = GemLike(MkrSkyLike(mkrSky).sky());
        rate = MkrSkyLike(mkrSky).rate();

        // Allow owner (pause proxy) to burn the sky in this contract, if ever needed to wind down
        sky.approve(owner, type(uint256).max);
    }

    function sync() external returns (bool isMint, uint256 amount) {
        uint256 mkrSupplyInSky = mkr.totalSupply() * rate;
        uint256 skyBalance     = sky.balanceOf(address(this));

        unchecked {
            if (mkrSupplyInSky > skyBalance) {
                isMint = true;
                amount = mkrSupplyInSky - skyBalance;
                sky.mint(address(this), amount);
            } else if (mkrSupplyInSky < skyBalance) {
                amount = skyBalance - mkrSupplyInSky;
                sky.burn(address(this), amount);
            }
        }
    }
}
