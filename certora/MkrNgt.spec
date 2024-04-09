// MkrNgt.spec

using Ngt as ngt;
using MkrMock as mkr;

methods {
    function rate() external returns (uint256) envfree;
    function ngt.wards(address) external returns (uint256) envfree;
    function ngt.totalSupply() external returns (uint256) envfree;
    function ngt.balanceOf(address) external returns (uint256) envfree;
    function ngt.allowance(address, address) external returns (uint256) envfree;
    function mkr.wards(address) external returns (uint256) envfree;
    function mkr.totalSupply() external returns (uint256) envfree;
    function mkr.balanceOf(address) external returns (uint256) envfree;
    function mkr.allowance(address, address) external returns (uint256) envfree;
}

ghost balanceSumNgt() returns mathint {
    init_state axiom balanceSumNgt() == 0;
}

hook Sstore ngt.balanceOf[KEY address a] uint256 balance (uint256 old_balance) {
    havoc balanceSumNgt assuming balanceSumNgt@new() == balanceSumNgt@old() + balance - old_balance && balanceSumNgt@new() >= 0;
}

invariant balanceSumNgt_equals_totalSupply() balanceSumNgt() == to_mathint(ngt.totalSupply());

ghost balanceSumMkr() returns mathint {
    init_state axiom balanceSumMkr() == 0;
}

hook Sstore mkr.balanceOf[KEY address a] uint256 balance (uint256 old_balance) {
    havoc balanceSumMkr assuming balanceSumMkr@new() == balanceSumMkr@old() + balance - old_balance && balanceSumMkr@new() >= 0;
}

invariant balanceSumMkr_equals_totalSupply() balanceSumMkr() == to_mathint(mkr.totalSupply());

// Verify correct storage changes for non reverting mkrToNgt
rule mkrToNgt(address usr, uint256 wad) {
    env e;

    require e.msg.sender != currentContract;

    requireInvariant balanceSumNgt_equals_totalSupply();
    requireInvariant balanceSumMkr_equals_totalSupply();

    address other;
    require other != usr;
    address other2;
    require other2 != e.msg.sender;

    mathint rate = rate();
    mathint ngtTotalSupplyBefore = ngt.totalSupply();
    mathint ngtBalanceOfUsrBefore = ngt.balanceOf(usr);
    mathint ngtBalanceOfOtherBefore = ngt.balanceOf(other);
    mathint mkrTotalSupplyBefore = mkr.totalSupply();
    mathint mkrBalanceOfSenderBefore = mkr.balanceOf(e.msg.sender);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other2);

    mkrToNgt(e, usr, wad);

    mathint ngtTotalSupplyAfter = ngt.totalSupply();
    mathint ngtBalanceOfUsrAfter = ngt.balanceOf(usr);
    mathint ngtBalanceOfOtherAfter = ngt.balanceOf(other);
    mathint mkrTotalSupplyAfter = mkr.totalSupply();
    mathint mkrBalanceOfSenderAfter = mkr.balanceOf(e.msg.sender);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other2);

    assert ngtTotalSupplyAfter == ngtTotalSupplyBefore + wad * rate, "mkrToNgt did not increase ngt.totalSupply by wad * rate";
    assert ngtBalanceOfUsrAfter == ngtBalanceOfUsrBefore + wad * rate, "mkrToNgt did not increase ngt.balanceOf[usr] by wad * rate";
    assert ngtBalanceOfOtherAfter == ngtBalanceOfOtherBefore, "mkrToNgt did not keep unchanged the rest of ngt.balanceOf[x]";
    assert mkrTotalSupplyAfter == mkrTotalSupplyBefore - wad, "mkrToNgt did not decrease mkr.totalSupply by wad";
    assert mkrBalanceOfSenderAfter == mkrBalanceOfSenderBefore - wad, "mkrToNgt did not decrease mkr.balanceOf[sender] by wad";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "mkrToNgt did not keep unchanged the rest of mkr.balanceOf[x]";
}

// Verify revert rules on mkrToNgt
rule mkrToNgt_revert(address usr, uint256 wad) {
    env e;

    requireInvariant balanceSumNgt_equals_totalSupply();
    requireInvariant balanceSumMkr_equals_totalSupply();

    require e.msg.sender != currentContract;

    mathint rate = rate();
    mathint mkrBalanceOfSender = mkr.balanceOf(e.msg.sender);
    mathint mkrAllowanceSenderMkrNgt = mkr.allowance(e.msg.sender, currentContract);
    mathint ngtWardsMkrNgt = ngt.wards(currentContract);
    mathint ngtTotalSupply = ngt.totalSupply();

    mkrToNgt@withrevert(e, usr, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = mkrBalanceOfSender < to_mathint(wad);
    bool revert3 = mkrAllowanceSenderMkrNgt < to_mathint(wad);
    bool revert4 = ngtWardsMkrNgt != 1;
    bool revert5 = ngtTotalSupply + wad * rate > max_uint256;
    bool revert6 = usr == 0 || usr == ngt;

    assert revert1 => lastReverted, "revert1 failed";
    assert revert2 => lastReverted, "revert2 failed";
    assert revert3 => lastReverted, "revert3 failed";
    assert revert4 => lastReverted, "revert4 failed";
    assert revert5 => lastReverted, "revert5 failed";
    assert revert6 => lastReverted, "revert6 failed";
    assert lastReverted => revert1 || revert2 || revert3 ||
                           revert4 || revert5 || revert6, "Revert rules are not covering all the cases";
}

// Verify correct storage changes for non reverting ngtToMkr
rule ngtToMkr(address usr, uint256 wad) {
    env e;

    require e.msg.sender != currentContract;

    requireInvariant balanceSumNgt_equals_totalSupply();
    requireInvariant balanceSumMkr_equals_totalSupply();

    address other;
    require other != e.msg.sender;
    address other2;
    require other2 != usr;

    mathint rate = rate();
    mathint ngtTotalSupplyBefore = ngt.totalSupply();
    mathint ngtBalanceOfSenderBefore = ngt.balanceOf(e.msg.sender);
    mathint ngtBalanceOfOtherBefore = ngt.balanceOf(other);
    mathint mkrTotalSupplyBefore = mkr.totalSupply();
    mathint mkrBalanceOfUsrBefore = mkr.balanceOf(usr);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other2);

    ngtToMkr(e, usr, wad);

    mathint ngtTotalSupplyAfter = ngt.totalSupply();
    mathint ngtBalanceOfSenderAfter = ngt.balanceOf(e.msg.sender);
    mathint ngtBalanceOfOtherAfter = ngt.balanceOf(other);
    mathint mkrTotalSupplyAfter = mkr.totalSupply();
    mathint mkrBalanceOfUsrAfter = mkr.balanceOf(usr);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other2);

    assert ngtTotalSupplyAfter == ngtTotalSupplyBefore - wad, "ngtToMkr did not decrease ngt.totalSupply by wad";
    assert ngtBalanceOfSenderAfter == ngtBalanceOfSenderBefore - wad, "ngtToMkr did not decrease ngt.balanceOf[sender] by wad";
    assert ngtBalanceOfOtherAfter == ngtBalanceOfOtherBefore, "ngtToMkr did not keep unchanged the rest of ngt.balanceOf[x]";
    assert mkrTotalSupplyAfter == mkrTotalSupplyBefore + wad / rate, "ngtToMkr did not increase mkr.totalSupply by wad / rate";
    assert mkrBalanceOfUsrAfter == mkrBalanceOfUsrBefore + wad / rate, "ngtToMkr did not increase mkr.balanceOf[usr] by wad / rate";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "ngtToMkr did not keep unchanged the rest of mkr.balanceOf[x]";
}

// Verify revert rules on ngtToMkr
rule ngtToMkr_revert(address usr, uint256 wad) {
    env e;

    requireInvariant balanceSumNgt_equals_totalSupply();
    requireInvariant balanceSumMkr_equals_totalSupply();

    require e.msg.sender != currentContract;

    mathint rate = rate();
    require rate > 0;
    mathint ngtBalanceOfSender = ngt.balanceOf(e.msg.sender);
    mathint ngtAllowanceSenderMkrNgt = ngt.allowance(e.msg.sender, currentContract);
    mathint mkrWardsMkrNgt = mkr.wards(currentContract);
    mathint mkrTotalSupply = mkr.totalSupply();

    ngtToMkr@withrevert(e, usr, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ngtBalanceOfSender < to_mathint(wad);
    bool revert3 = ngtAllowanceSenderMkrNgt < to_mathint(wad);
    bool revert4 = mkrWardsMkrNgt != 1;
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
