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

pragma solidity >=0.8.0;

import { DssInstance } from "dss-test/MCD.sol";
import { NgtInstance } from "./NgtInstance.sol";

interface NgtLike {
    function rely(address) external;
}

interface MkrNgtLike {
    function mkr() external view returns (address);
    function ngt() external view returns (address);
    function rate() external view returns (uint256);
}

interface MkrLike {
    function authority() external view returns (address);
}

interface MkrAuthorityLike {
    function rely(address) external;
}

library NgtInit {
    function init(
        DssInstance memory dss,
        NgtInstance memory instance,
        uint256 rate
    ) internal {
        address mkr = dss.chainlog.getAddress("MCD_GOV");
        require(MkrNgtLike(instance.mkrNgt).mkr()  == mkr,          "NgtInit/mkr-does-not-match");
        require(MkrNgtLike(instance.mkrNgt).ngt()  == instance.ngt, "NgtInit/ngt-does-not-match");
        require(MkrNgtLike(instance.mkrNgt).rate() == rate,         "NgtInit/rate-does-not-match");

        NgtLike(instance.ngt).rely(instance.mkrNgt);
        MkrAuthorityLike(MkrLike(mkr).authority()).rely(instance.mkrNgt);

        dss.chainlog.setAddress("NGT",     instance.ngt);
        dss.chainlog.setAddress("MKR_NGT", instance.mkrNgt);
    }
}
