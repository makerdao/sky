// SPDX-License-Identifier: AGPL-3.0-or-later

/// MkrNgt.sol -- Mkr/Ngt Exchanger

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

pragma solidity ^0.8.16;


interface GemLike {
    function burn(address, uint256) external;
    function mint(address, uint256) external;
}

interface VatLike {
    function hope(address) external;
}

contract MkrNgt {
    GemLike public immutable mkr;
    GemLike public immutable ngt;
    uint256 public immutable rate;
    
    event MkrToNgt(address indexed caller, address indexed usr, uint256 wad);
    event NgtToMkr(address indexed caller, address indexed usr, uint256 wad);

    constructor(address mkr_, address ngt_, uint256 rate_) {
        mkr  = GemLike(mkr_);
        ngt  = GemLike(ngt_);
        rate = rate_; 
    }

    function mkrToNgt(address usr, uint256 mkrAmt) external {
        mkr.burn(msg.sender, mkrAmt);
        ngt.mint(usr, mkrAmt * rate);
        emit MkrToNgt(msg.sender, usr, mkrAmt);
    }

    function ngtToMkr(address usr, uint256 mkrAmt) external {
        ngt.burn(msg.sender, mkrAmt * rate);
        mkr.mint(usr, mkrAmt);
        emit NgtToMkr(msg.sender, usr, mkrAmt);
    }
}
