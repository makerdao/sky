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
    uint256 public rate;
    
    event MkrToNgt(uint256 wad);
    event NgtToMkr(uint256 wad);

    constructor(address mkr_, address ngt_, uint256 rate_) {
        mkr  = GemLike(mkr_);
        ngt  = GemLike(ngt_);
        rate = rate_; 
    }

    function mkrToNgt(uint256 mkrAmt) external {
        mkr.burn(msg.sender, mkrAmt);
        ngt.mint(msg.sender, mkrAmt * rate);
        emit MkrToNgt(mkrAmt);
    }

    function ngtToMkr(uint256 mkrAmt) external {
        ngt.burn(msg.sender, mkrAmt * rate);
        mkr.mint(msg.sender, mkrAmt);
        emit NgtToMkr(mkrAmt);
    }
}
