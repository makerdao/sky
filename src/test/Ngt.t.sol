// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.16;

import "token-tests/TokenFuzzTests.sol";

import { Ngt } from "../Ngt.sol";

contract NgtTest is TokenFuzzTests {
    Ngt ngt;

    function setUp() public {
        vm.expectEmit(true, true, true, true);
        emit Rely(address(this));
        ngt = new Ngt();
  
        _token_ = address(ngt);
        _contractName_ = "Ngt";
        _tokenName_ ="NstDAO Governance Token";
        _symbol_ = "NGT";
    }

    function invariantMetadata() public {
        assertEq(ngt.name(), "NstDAO Governance Token");
        assertEq(ngt.symbol(), "NGT");
        assertEq(ngt.version(), "1");
        assertEq(ngt.decimals(), 18);
    }
}
