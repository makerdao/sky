// MkrSky.spec

using Sky as sky;
using MkrMock as mkr;

methods {
    //
    function wards(address) external returns (uint256) envfree;
    function fee() external returns (uint256) envfree;
    function take() external returns (uint256) envfree;
    //
    function rate() external returns (uint256) envfree;
    //
    function sky.wards(address) external returns (uint256) envfree;
    function sky.totalSupply() external returns (uint256) envfree;
    function sky.balanceOf(address) external returns (uint256) envfree;
    function sky.allowance(address, address) external returns (uint256) envfree;
    function mkr.wards(address) external returns (uint256) envfree;
    function mkr.totalSupply() external returns (uint256) envfree;
    function mkr.balanceOf(address) external returns (uint256) envfree;
    function mkr.allowance(address, address) external returns (uint256) envfree;
}

definition WAD() returns mathint = 10^18;

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

// Verify no more entry points exist
rule entryPoints(method f) filtered { f -> !f.isView } {
    env e;

    calldataarg args;
    f(e, args);

    assert f.selector == sig:rely(address).selector ||
           f.selector == sig:deny(address).selector ||
           f.selector == sig:file(bytes32,uint256).selector ||
           f.selector == sig:collect(address).selector ||
           f.selector == sig:burn(uint256).selector ||
           f.selector == sig:mkrToSky(address,uint256).selector;
}

// Verify that each storage layout is only modified in the corresponding functions
rule storageAffected(method f) {
    env e;

    address anyAddr;

    mathint wardsBefore = wards(anyAddr);
    mathint feeBefore = fee();
    mathint takeBefore = take();

    calldataarg args;
    f(e, args);

    mathint wardsAfter = wards(anyAddr);
    mathint feeAfter = fee();
    mathint takeAfter = take();

    assert wardsAfter != wardsBefore => f.selector == sig:rely(address).selector || f.selector == sig:deny(address).selector, "Assert 1";
    assert feeAfter != feeBefore => f.selector == sig:file(bytes32,uint256).selector, "Assert 2";
    assert takeAfter != takeBefore => f.selector == sig:collect(address).selector || f.selector == sig:mkrToSky(address,uint256).selector, "Assert 3";
}

// Verify correct storage changes for non reverting rely
rule rely(address usr) {
    env e;

    address other;
    require other != usr;

    mathint wardsOtherBefore = wards(other);

    rely(e, usr);

    mathint wardsUsrAfter = wards(usr);
    mathint wardsOtherAfter = wards(other);

    assert wardsUsrAfter == 1, "Assert 1";
    assert wardsOtherAfter == wardsOtherBefore, "Assert 2";
}

// Verify revert rules on rely
rule rely_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    rely@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting deny
rule deny(address usr) {
    env e;

    address other;
    require other != usr;

    mathint wardsOtherBefore = wards(other);

    deny(e, usr);

    mathint wardsUsrAfter = wards(usr);
    mathint wardsOtherAfter = wards(other);

    assert wardsUsrAfter == 0, "Assert 1";
    assert wardsOtherAfter == wardsOtherBefore, "Assert 2";
}

// Verify revert rules on deny
rule deny_revert(address usr) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    deny@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting file
rule file(bytes32 what, uint256 data) {
    env e;

    file(e, what, data);

    uint256 feeAfter = fee();

    assert feeAfter == data, "Assert 1";
}

// Verify revert rules on file
rule file_revert(bytes32 what, uint256 data) {
    env e;

    mathint wardsSender = wards(e.msg.sender);

    file@withrevert(e, what, data);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = what != to_bytes32(0x6665650000000000000000000000000000000000000000000000000000000000);
    bool revert4 = what == to_bytes32(0x6665650000000000000000000000000000000000000000000000000000000000) && data > WAD();

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4, "Revert rules failed";
}

// Verify correct storage changes for non reverting collect
rule collect(address to) {
    env e;

    address other;
    require other != currentContract && other != to;

    requireInvariant balanceSumSky_equals_totalSupply();

    mathint takeBefore = take();
    mathint skyBalanceOfMkrSkyBefore = sky.balanceOf(currentContract);
    mathint skyBalanceOfToBefore = sky.balanceOf(to);
    mathint skyBalanceOfOtherBefore = sky.balanceOf(other);

    uint256 retTake = collect(e, to);

    mathint takeAfter = take();
    mathint skyBalanceOfMkrSkyAfter = sky.balanceOf(currentContract);
    mathint skyBalanceOfToAfter = sky.balanceOf(to);
    mathint skyBalanceOfOtherAfter = sky.balanceOf(other);

    assert retTake == takeBefore, "Assert 1";
    assert takeAfter == 0, "Assert 2";
    assert to != currentContract => skyBalanceOfMkrSkyAfter == skyBalanceOfMkrSkyBefore - takeBefore, "Assert 3";
    assert to != currentContract => skyBalanceOfToAfter == skyBalanceOfToBefore + takeBefore, "Assert 4";
    assert to == currentContract => skyBalanceOfMkrSkyAfter == skyBalanceOfMkrSkyBefore, "Assert 5";
    assert skyBalanceOfOtherAfter == skyBalanceOfOtherBefore, "Assert 6";
}

// Verify revert rules on collect
rule collect_revert(address to) {
    env e;

    requireInvariant balanceSumSky_equals_totalSupply();

    mathint wardsSender = wards(e.msg.sender);
    mathint take = take();
    mathint skyBalanceOfMkrSky = sky.balanceOf(currentContract);

    require skyBalanceOfMkrSky >= take;

    collect@withrevert(e, to);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = take == 0;
    bool revert4 = to == 0 || to == sky;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4, "Revert rules failed";
}

// Verify correct storage changes for non reverting burn
rule burn(uint256 skyAmt) {
    env e;

    address other;
    require other != currentContract;

    requireInvariant balanceSumSky_equals_totalSupply();

    mathint skyTotalSupplyBefore = sky.totalSupply();
    mathint skyBalanceOfMkrSkyBefore = sky.balanceOf(currentContract);
    mathint skyBalanceOfOtherBefore = sky.balanceOf(other);

    burn(e, skyAmt);

    mathint skyTotalSupplyAfter = sky.totalSupply();
    mathint skyBalanceOfMkrSkyAfter = sky.balanceOf(currentContract);
    mathint skyBalanceOfOtherAfter = sky.balanceOf(other);

    assert skyTotalSupplyAfter == skyTotalSupplyBefore - skyAmt, "Assert 1";
    assert skyBalanceOfMkrSkyAfter == skyBalanceOfMkrSkyBefore - skyAmt, "Assert 2";
    assert skyBalanceOfOtherAfter == skyBalanceOfOtherBefore, "Assert 3";
}

// Verify revert rules on burn
rule burn_revert(uint256 skyAmt) {
    env e;

    requireInvariant balanceSumSky_equals_totalSupply();

    mathint wardsSender = wards(e.msg.sender);
    mathint skyBalanceOfMkrSky = sky.balanceOf(currentContract);

    burn@withrevert(e, skyAmt);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = skyBalanceOfMkrSky < skyAmt;

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}

// Verify correct storage changes for non reverting mkrToSky
rule mkrToSky(address usr, uint256 mkrAmt) {
    env e;

    require e.msg.sender != currentContract;

    requireInvariant balanceSumSky_equals_totalSupply();
    requireInvariant balanceSumMkr_equals_totalSupply();

    address other;
    require other != currentContract && other != usr;
    address other2;
    require other2 != e.msg.sender;

    mathint fee = fee();
    // file restriction
    require fee <= WAD();
    mathint rate = rate();
    mathint takeBefore = take();
    mathint skyTotalSupplyBefore = sky.totalSupply();
    mathint skyBalanceOfMkrSkyBefore = sky.balanceOf(currentContract);
    mathint skyBalanceOfUsrBefore = sky.balanceOf(usr);
    mathint skyBalanceOfOtherBefore = sky.balanceOf(other);
    mathint mkrTotalSupplyBefore = mkr.totalSupply();
    mathint mkrBalanceOfSenderBefore = mkr.balanceOf(e.msg.sender);
    mathint mkrBalanceOfOtherBefore = mkr.balanceOf(other2);

    mathint skyFee = mkrAmt * rate * fee / WAD();
    mathint skyAmt = mkrAmt * rate - skyFee;

    mkrToSky(e, usr, mkrAmt);

    mathint takeAfter = take();
    mathint skyTotalSupplyAfter = sky.totalSupply();
    mathint skyBalanceOfMkrSkyAfter = sky.balanceOf(currentContract);
    mathint skyBalanceOfUsrAfter = sky.balanceOf(usr);
    mathint skyBalanceOfOtherAfter = sky.balanceOf(other);
    mathint mkrTotalSupplyAfter = mkr.totalSupply();
    mathint mkrBalanceOfSenderAfter = mkr.balanceOf(e.msg.sender);
    mathint mkrBalanceOfOtherAfter = mkr.balanceOf(other2);

    assert takeAfter == takeBefore + skyFee, "Assert 1";
    assert skyTotalSupplyAfter == skyTotalSupplyBefore, "Assert 2";
    assert usr != currentContract => skyBalanceOfMkrSkyAfter == skyBalanceOfMkrSkyBefore - skyAmt, "Assert 3";
    assert usr != currentContract => skyBalanceOfUsrAfter == skyBalanceOfUsrBefore + skyAmt, "Assert 4";
    assert usr == currentContract => skyBalanceOfUsrAfter == skyBalanceOfUsrBefore, "Assert 5";
    assert skyBalanceOfOtherAfter == skyBalanceOfOtherBefore, "Assert 6";
    assert mkrTotalSupplyAfter == mkrTotalSupplyBefore - mkrAmt, "Assert 7";
    assert mkrBalanceOfSenderAfter == mkrBalanceOfSenderBefore - mkrAmt, "Assert 8";
    assert mkrBalanceOfOtherAfter == mkrBalanceOfOtherBefore, "Assert 9";
}

// Verify revert rules on mkrToSky
rule mkrToSky_revert(address usr, uint256 mkrAmt) {
    env e;

    requireInvariant balanceSumSky_equals_totalSupply();
    requireInvariant balanceSumMkr_equals_totalSupply();

    require e.msg.sender != currentContract;

    mathint fee = fee();
    // file restriction
    require fee <= WAD();
    mathint rate = rate();
    mathint take = take();
    mathint mkrBalanceOfSender = mkr.balanceOf(e.msg.sender);
    mathint mkrAllowanceSenderMkrSky = mkr.allowance(e.msg.sender, currentContract);
    mathint skyBalanceOfMkrSky = sky.balanceOf(currentContract);

    mathint skyFee = mkrAmt * rate * fee / WAD();
    mathint skyAmt = mkrAmt * rate - skyFee;

    mkrToSky@withrevert(e, usr, mkrAmt);

    bool revert1 = e.msg.value > 0;
    bool revert2 = mkrAmt * rate > max_uint256;
    bool revert3 = mkrAmt * rate * fee > max_uint256;
    bool revert4 = take + skyFee > max_uint256;
    bool revert5 = mkrBalanceOfSender < to_mathint(mkrAmt);
    bool revert6 = mkrAllowanceSenderMkrSky < to_mathint(mkrAmt);
    bool revert7 = skyBalanceOfMkrSky < skyAmt;
    bool revert8 = usr == 0 || usr == sky;

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4 || revert5 || revert6 ||
                            revert7 || revert8, "Revert rules failed";
}
