// MkrSky.spec

using Sky as sky;
using MkrMock as mkr;

methods {
    function rate() external returns (uint256) envfree;
    function sky.wards(address) external returns (uint256) envfree;
    function sky.totalSupply() external returns (uint256) envfree;
    function sky.balanceOf(address) external returns (uint256) envfree;
    function sky.allowance(address, address) external returns (uint256) envfree;
    function mkr.wards(address) external returns (uint256) envfree;
    function mkr.totalSupply() external returns (uint256) envfree;
    function mkr.balanceOf(address) external returns (uint256) envfree;
    function mkr.allowance(address, address) external returns (uint256) envfree;
}

ghost balanceSumSky() returns mathint {
    init_state axiom balanceSumSky() == 0;
}

hook Sstore sky.balanceOf[KEY address a] uint256 balance (uint256 old_balance) {
    havoc balanceSumSky assuming balanceSumSky@new() == balanceSumSky@old() + balance - old_balance && balanceSumSky@new() >= 0;
}

invariant balanceSumSky_equals_totalSupply() balanceSumSky() == to_mathint(sky.totalSupply());

ghost balanceSumMkr() returns mathint {
    init_state axiom balanceSumMkr() == 0;
}

hook Sstore mkr.balanceOf[KEY address a] uint256 balance (uint256 old_balance) {
    havoc balanceSumMkr assuming balanceSumMkr@new() == balanceSumMkr@old() + balance - old_balance && balanceSumMkr@new() >= 0;
}

invariant balanceSumMkr_equals_totalSupply() balanceSumMkr() == to_mathint(mkr.totalSupply());

// Verify correct storage changes for non reverting mkrToSky
rule mkrToSky(address usr, uint256 wad) {
    env e;

    require e.msg.sender != currentContract;

    requireInvariant balanceSumSky_equals_totalSupply();
    requireInvariant balanceSumMkr_equals_totalSupply();

    address other;
    require other != usr;
    address other2;
    require other2 != e.msg.sender;

    mathint rate = rate();
    mathint skyTotalSupplyBefore = sky.totalSupply();
    mathint skyBalanceOfUsrBefore = sky.balanceOf(usr);
    mathint skyBalanceOfOtherBefore = sky.balanceOf(other);
    mathint mkrTotalSupplyBefore = mkr.totalSupply();
    mathint mkrBalanceOfSenderBefore = mkr.balanceOf(e.msg.sender);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other2);

    mkrToSky(e, usr, wad);

    mathint skyTotalSupplyAfter = sky.totalSupply();
    mathint skyBalanceOfUsrAfter = sky.balanceOf(usr);
    mathint skyBalanceOfOtherAfter = sky.balanceOf(other);
    mathint mkrTotalSupplyAfter = mkr.totalSupply();
    mathint mkrBalanceOfSenderAfter = mkr.balanceOf(e.msg.sender);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other2);

    assert skyTotalSupplyAfter == skyTotalSupplyBefore + wad * rate, "mkrToSky did not increase sky.totalSupply by wad * rate";
    assert skyBalanceOfUsrAfter == skyBalanceOfUsrBefore + wad * rate, "mkrToSky did not increase sky.balanceOf[usr] by wad * rate";
    assert skyBalanceOfOtherAfter == skyBalanceOfOtherBefore, "mkrToSky did not keep unchanged the rest of sky.balanceOf[x]";
    assert mkrTotalSupplyAfter == mkrTotalSupplyBefore - wad, "mkrToSky did not decrease mkr.totalSupply by wad";
    assert mkrBalanceOfSenderAfter == mkrBalanceOfSenderBefore - wad, "mkrToSky did not decrease mkr.balanceOf[sender] by wad";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "mkrToSky did not keep unchanged the rest of mkr.balanceOf[x]";
}

// Verify revert rules on mkrToSky
rule mkrToSky_revert(address usr, uint256 wad) {
    env e;

    requireInvariant balanceSumSky_equals_totalSupply();
    requireInvariant balanceSumMkr_equals_totalSupply();

    require e.msg.sender != currentContract;

    mathint rate = rate();
    mathint mkrBalanceOfSender = mkr.balanceOf(e.msg.sender);
    mathint mkrAllowanceSenderMkrSky = mkr.allowance(e.msg.sender, currentContract);
    mathint skyWardsMkrSky = sky.wards(currentContract);
    mathint skyTotalSupply = sky.totalSupply();

    mkrToSky@withrevert(e, usr, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = mkrBalanceOfSender < to_mathint(wad);
    bool revert3 = mkrAllowanceSenderMkrSky < to_mathint(wad);
    bool revert4 = skyWardsMkrSky != 1;
    bool revert5 = skyTotalSupply + wad * rate > max_uint256;
    bool revert6 = usr == 0 || usr == sky;

    assert revert1 => lastReverted, "revert1 failed";
    assert revert2 => lastReverted, "revert2 failed";
    assert revert3 => lastReverted, "revert3 failed";
    assert revert4 => lastReverted, "revert4 failed";
    assert revert5 => lastReverted, "revert5 failed";
    assert revert6 => lastReverted, "revert6 failed";
    assert lastReverted => revert1 || revert2 || revert3 ||
                           revert4 || revert5 || revert6, "Revert rules are not covering all the cases";
}

// Verify correct storage changes for non reverting skyToMkr
rule skyToMkr(address usr, uint256 wad) {
    env e;

    require e.msg.sender != currentContract;

    requireInvariant balanceSumSky_equals_totalSupply();
    requireInvariant balanceSumMkr_equals_totalSupply();

    address other;
    require other != e.msg.sender;
    address other2;
    require other2 != usr;

    mathint rate = rate();
    mathint skyTotalSupplyBefore = sky.totalSupply();
    mathint skyBalanceOfSenderBefore = sky.balanceOf(e.msg.sender);
    mathint skyBalanceOfOtherBefore = sky.balanceOf(other);
    mathint mkrTotalSupplyBefore = mkr.totalSupply();
    mathint mkrBalanceOfUsrBefore = mkr.balanceOf(usr);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other2);

    skyToMkr(e, usr, wad);

    mathint skyTotalSupplyAfter = sky.totalSupply();
    mathint skyBalanceOfSenderAfter = sky.balanceOf(e.msg.sender);
    mathint skyBalanceOfOtherAfter = sky.balanceOf(other);
    mathint mkrTotalSupplyAfter = mkr.totalSupply();
    mathint mkrBalanceOfUsrAfter = mkr.balanceOf(usr);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other2);

    assert skyTotalSupplyAfter == skyTotalSupplyBefore - wad, "skyToMkr did not decrease sky.totalSupply by wad";
    assert skyBalanceOfSenderAfter == skyBalanceOfSenderBefore - wad, "skyToMkr did not decrease sky.balanceOf[sender] by wad";
    assert skyBalanceOfOtherAfter == skyBalanceOfOtherBefore, "skyToMkr did not keep unchanged the rest of sky.balanceOf[x]";
    assert mkrTotalSupplyAfter == mkrTotalSupplyBefore + wad / rate, "skyToMkr did not increase mkr.totalSupply by wad / rate";
    assert mkrBalanceOfUsrAfter == mkrBalanceOfUsrBefore + wad / rate, "skyToMkr did not increase mkr.balanceOf[usr] by wad / rate";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "skyToMkr did not keep unchanged the rest of mkr.balanceOf[x]";
}

// Verify revert rules on skyToMkr
rule skyToMkr_revert(address usr, uint256 wad) {
    env e;

    requireInvariant balanceSumSky_equals_totalSupply();
    requireInvariant balanceSumMkr_equals_totalSupply();

    require e.msg.sender != currentContract;

    mathint rate = rate();
    require rate > 0;
    mathint skyBalanceOfSender = sky.balanceOf(e.msg.sender);
    mathint skyAllowanceSenderMkrSky = sky.allowance(e.msg.sender, currentContract);
    mathint mkrWardsMkrSky = mkr.wards(currentContract);
    mathint mkrTotalSupply = mkr.totalSupply();

    skyToMkr@withrevert(e, usr, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = skyBalanceOfSender < to_mathint(wad);
    bool revert3 = skyAllowanceSenderMkrSky < to_mathint(wad);
    bool revert4 = mkrWardsMkrSky != 1;
    bool revert5 = mkrTotalSupply + wad / rate > max_uint256;
    bool revert6 = usr == 0 || usr == mkr;

    assert revert1 => lastReverted, "revert1 failed";
    assert revert2 => lastReverted, "revert2 failed";
    assert revert3 => lastReverted, "revert3 failed";
    assert revert4 => lastReverted, "revert4 failed";
    assert revert5 => lastReverted, "revert5 failed";
    assert revert6 => lastReverted, "revert6 failed";
    assert lastReverted => revert1 || revert2 || revert3 ||
                           revert4 || revert5 || revert6, "Revert rules are not covering all the cases";
}
