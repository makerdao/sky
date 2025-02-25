// SPDX-License-Identifier: AGPL-3.0-or-later

/// MkrSky.sol -- Mkr/Sky Exchanger

// Copyright (C) 2023 Dai Foundation
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
    function burn(address, uint256) external;
    function transfer(address, uint256) external;
}

contract MkrSky {
    mapping (address => uint256) public wards;
    uint256                      public fee;
    uint256                      public take; // accumulated SKY fee available for collection

    uint256 constant WAD = 10**18;

    GemLike public immutable mkr;
    GemLike public immutable sky;
    uint256 public immutable rate;

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event File(bytes32 indexed what, uint256 data);
    event Collect(address indexed to, uint256 take);
    event Burn(uint256 skyAmt);
    event MkrToSky(address indexed caller, address indexed usr, uint256 mkrAmt, uint256 skyAmt, uint256 skyFee);

    modifier auth {
        require(wards[msg.sender] == 1, "MkrSky/not-authorized");
        _;
    }

    constructor(address mkr_, address sky_, uint256 rate_) {
        mkr  = GemLike(mkr_);
        sky  = GemLike(sky_);
        rate = rate_;

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // Admin functions

    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    function file(bytes32 what, uint256 data) external auth {
        if (what == "fee") {
            require(data <= WAD, "MkrSky/fee-exceeds-wad");
            fee = data;
        } else revert("MkrSky/file-unrecognized-param");
        emit File(what, data);
    }

    function collect(address to) external auth returns (uint256 take_) {
        take_ = take;
        require(take_ > 0, "MkrSky/nothing-to-collect");
        take = 0;
        sky.transfer(to, take_);
        emit Collect(to, take_);
    }

    // This function is intended to be used when deactivating this contract or for burning excess SKY due to MKR being burned.
    // If needed, making sure that the `take` amount is not burned is assumed to be done on a higher level (e.g by calling `collect` first).
    function burn(uint256 skyAmt) external auth {
        sky.burn(address(this), skyAmt);
        emit Burn(skyAmt);
    }

    // Public functions

    function mkrToSky(address usr, uint256 mkrAmt) external {
        uint256 skyAmt = mkrAmt * rate;
        uint256 skyFee;
        uint256 fee_ = fee;
        if (fee_ > 0) {
            skyFee = skyAmt * fee_ / WAD;
            unchecked { skyAmt -= skyFee; }
            take += skyFee;
        }

        mkr.burn(msg.sender, mkrAmt);
        sky.transfer(usr, skyAmt);
        emit MkrToSky(msg.sender, usr, mkrAmt, skyAmt, skyFee);
    }
}
