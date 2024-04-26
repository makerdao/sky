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

pragma solidity ^0.8.21;

interface GemLike {
    function burn(address, uint256) external;
    function mint(address, uint256) external;
}

contract MkrNgt {
    GemLike public immutable mkr;
    GemLike public immutable ngt;
    uint256 public immutable rate;
    
    event MkrToNgt(address indexed caller, address indexed usr, uint256 mkrAmt, uint256 ngtAmt);
    event NgtToMkr(address indexed caller, address indexed usr, uint256 ngtAmt, uint256 mkrAmt);

    constructor(address mkr_, address ngt_, uint256 rate_) {
        mkr  = GemLike(mkr_);
        ngt  = GemLike(ngt_);
        rate = rate_; 
    }

    function mkrToNgt(address usr, uint256 mkrAmt) external {
        mkr.burn(msg.sender, mkrAmt);
        uint256 ngtAmt = mkrAmt * rate;
        ngt.mint(usr, ngtAmt);
        emit MkrToNgt(msg.sender, usr, mkrAmt, ngtAmt);
    }

    function ngtToMkr(address usr, uint256 ngtAmt) external {
        ngt.burn(msg.sender, ngtAmt);
        uint256 mkrAmt = ngtAmt / rate; // Rounding down, dust will be lost if it is not multiple of rate
        mkr.mint(usr, mkrAmt);
        emit NgtToMkr(msg.sender, usr, ngtAmt, mkrAmt);
    }
}
