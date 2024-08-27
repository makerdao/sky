// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import "token-tests/TokenFuzzTests.sol";

import { Sky } from "src/Sky.sol";

contract SkyTest is TokenFuzzTests {
    Sky sky;

    function setUp() public {
        vm.expectEmit(true, true, true, true);
        emit Rely(address(this));
        sky = new Sky();
  
        _token_ = address(sky);
        _contractName_ = "Sky";
        _tokenName_ = "SKY Governance Token";
        _symbol_ = "SKY";
    }

    function invariantMetadata() public view {
        assertEq(sky.name(), "SKY Governance Token");
        assertEq(sky.symbol(), "SKY");
        assertEq(sky.version(), "1");
        assertEq(sky.decimals(), 18);
    }
}
