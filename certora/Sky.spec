// Sky.spec

using Auxiliar as aux;
using SignerMock as signer;

methods {
    function wards(address) external returns (uint256) envfree;
    function name() external returns (string) envfree;
    function symbol() external returns (string) envfree;
    function version() external returns (string) envfree;
    function decimals() external returns (uint8) envfree;
    function totalSupply() external returns (uint256) envfree;
    function balanceOf(address) external returns (uint256) envfree;
    function allowance(address, address) external returns (uint256) envfree;
    function nonces(address) external returns (uint256) envfree;
    function deploymentChainId() external returns (uint256) envfree;
    function DOMAIN_SEPARATOR() external returns (bytes32) envfree;
    function PERMIT_TYPEHASH() external returns (bytes32) envfree;
    function aux.call_ecrecover(bytes32, uint8, bytes32, bytes32) external returns (address) envfree;
    function aux.computeDigestForToken(bytes32, bytes32, address, address, uint256, uint256, uint256) external returns (bytes32) envfree;
    function aux.signatureToVRS(bytes) external returns (uint8, bytes32, bytes32) envfree;
    function aux.VRSToSignature(uint8, bytes32, bytes32) external returns (bytes) envfree;
    function aux.size(bytes) external returns (uint256) envfree;
    function _.isValidSignature(bytes32, bytes) external => DISPATCHER(true);
}

ghost balanceSum() returns mathint {
    init_state axiom balanceSum() == 0;
}

hook Sstore balanceOf[KEY address a] uint256 balance (uint256 old_balance) {
    havoc balanceSum assuming balanceSum@new() == balanceSum@old() + balance - old_balance && balanceSum@new() >= 0;
}

invariant balanceSum_equals_totalSupply() balanceSum() == to_mathint(totalSupply());

// Verify no more entry points exist
rule entryPoints(method f) filtered { f -> !f.isView } {
    env e;

    calldataarg args;
    f(e, args);

    assert f.selector == sig:rely(address).selector ||
           f.selector == sig:deny(address).selector ||
           f.selector == sig:transfer(address,uint256).selector ||
           f.selector == sig:transferFrom(address,address,uint256).selector ||
           f.selector == sig:approve(address,uint256).selector ||
           f.selector == sig:mint(address,uint256).selector ||
           f.selector == sig:burn(address,uint256).selector ||
           f.selector == sig:permit(address,address,uint256,uint256,bytes).selector ||
           f.selector == sig:permit(address,address,uint256,uint256,uint8,bytes32,bytes32).selector;
}

// Verify that each storage layout is only modified in the corresponding functions
rule storageAffected(method f) {
    env e;

    address anyAddr;
    address anyAddr2;

    mathint wardsBefore = wards(anyAddr);
    mathint totalSupplyBefore = totalSupply();
    mathint balanceOfBefore = balanceOf(anyAddr);
    mathint allowanceBefore = allowance(anyAddr, anyAddr2);
    mathint noncesBefore = nonces(anyAddr);

    calldataarg args;
    f(e, args);

    mathint wardsAfter = wards(anyAddr);
    mathint totalSupplyAfter = totalSupply();
    mathint balanceOfAfter = balanceOf(anyAddr);
    mathint allowanceAfter = allowance(anyAddr, anyAddr2);
    mathint noncesAfter = nonces(anyAddr);

    assert wardsAfter != wardsBefore             => f.selector == sig:rely(address).selector ||
                                                    f.selector == sig:deny(address).selector, "Assert 1";
    assert totalSupplyAfter != totalSupplyBefore => f.selector == sig:mint(address,uint256).selector ||
                                                    f.selector == sig:burn(address,uint256).selector, "Assert 2";
    assert balanceOfAfter != balanceOfBefore     => f.selector == sig:mint(address,uint256).selector ||
                                                    f.selector == sig:burn(address,uint256).selector ||
                                                    f.selector == sig:transfer(address,uint256).selector ||
                                                    f.selector == sig:transferFrom(address,address,uint256).selector, "Assert 3";
    assert allowanceAfter != allowanceBefore     => f.selector == sig:approve(address,uint256).selector ||
                                                    f.selector == sig:transferFrom(address,address,uint256).selector ||
                                                    f.selector == sig:burn(address,uint256).selector ||
                                                    f.selector == sig:permit(address,address,uint256,uint256,bytes).selector ||
                                                    f.selector == sig:permit(address,address,uint256,uint256,uint8,bytes32,bytes32).selector, "Assert 4";
    assert noncesAfter != noncesBefore           => f.selector == sig:permit(address,address,uint256,uint256,bytes).selector ||
                                                    f.selector == sig:permit(address,address,uint256,uint256,uint8,bytes32,bytes32).selector, "Assert 5";
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

// Verify correct storage changes for non reverting transfer
rule transfer(address to, uint256 value) {
    env e;

    requireInvariant balanceSum_equals_totalSupply();

    address other;
    require other != e.msg.sender && other != to;

    mathint balanceOfSenderBefore = balanceOf(e.msg.sender);
    mathint balanceOfToBefore = balanceOf(to);
    mathint balanceOfOtherBefore = balanceOf(other);

    transfer(e, to, value);

    mathint balanceOfSenderAfter = balanceOf(e.msg.sender);
    mathint balanceOfToAfter = balanceOf(to);
    mathint balanceOfOtherAfter = balanceOf(other);

    assert e.msg.sender != to => balanceOfSenderAfter == balanceOfSenderBefore - value, "Assert 1";
    assert e.msg.sender != to => balanceOfToAfter == balanceOfToBefore + value, "Assert 2";
    assert e.msg.sender == to => balanceOfSenderAfter == balanceOfSenderBefore, "Assert 3";
    assert balanceOfOtherAfter == balanceOfOtherBefore, "Assert 4";
}

// Verify revert rules on transfer
rule transfer_revert(address to, uint256 value) {
    env e;

    mathint balanceOfSender = balanceOf(e.msg.sender);

    transfer@withrevert(e, to, value);

    bool revert1 = e.msg.value > 0;
    bool revert2 = to == 0 || to == currentContract;
    bool revert3 = balanceOfSender < to_mathint(value);

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}

// Verify correct storage changes for non reverting transferFrom
rule transferFrom(address from, address to, uint256 value) {
    env e;

    requireInvariant balanceSum_equals_totalSupply();

    address other;
    require other != from && other != to;
    address other2; address other3;
    require other2 != from || other3 != e.msg.sender;

    mathint totalSupplyBefore = totalSupply();
    mathint balanceOfFromBefore = balanceOf(from);
    mathint balanceOfToBefore = balanceOf(to);
    mathint balanceOfOtherBefore = balanceOf(other);
    mathint allowanceFromSenderBefore = allowance(from, e.msg.sender);
    mathint allowanceOtherBefore = allowance(other2, other3);

    transferFrom(e, from, to, value);

    mathint balanceOfFromAfter = balanceOf(from);
    mathint balanceOfToAfter = balanceOf(to);
    mathint balanceOfOtherAfter = balanceOf(other);
    mathint allowanceFromSenderAfter = allowance(from, e.msg.sender);
    mathint allowanceOtherAfter = allowance(other2, other3);

    assert from != to => balanceOfFromAfter == balanceOfFromBefore - value, "Assert 1";
    assert from != to => balanceOfToAfter == balanceOfToBefore + value, "Assert 2";
    assert from == to => balanceOfFromAfter == balanceOfFromBefore, "Assert 3";
    assert balanceOfOtherAfter == balanceOfOtherBefore, "Assert 4";
    assert e.msg.sender != from && allowanceFromSenderBefore != max_uint256 => allowanceFromSenderAfter == allowanceFromSenderBefore - value, "Assert 5";
    assert e.msg.sender == from => allowanceFromSenderAfter == allowanceFromSenderBefore, "Assert 6";
    assert allowanceFromSenderBefore == max_uint256 => allowanceFromSenderAfter == allowanceFromSenderBefore, "Assert 7";
    assert allowanceOtherAfter == allowanceOtherBefore, "Assert 8";
}

// Verify revert rules on transferFrom
rule transferFrom_revert(address from, address to, uint256 value) {
    env e;

    mathint balanceOfFrom = balanceOf(from);
    mathint allowanceFromSender = allowance(from, e.msg.sender);

    transferFrom@withrevert(e, from, to, value);

    bool revert1 = e.msg.value > 0;
    bool revert2 = to == 0 || to == currentContract;
    bool revert3 = balanceOfFrom < to_mathint(value);
    bool revert4 = allowanceFromSender < to_mathint(value) && e.msg.sender != from;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4, "Revert rules failed";
}

// Verify correct storage changes for non reverting approve
rule approve(address spender, uint256 value) {
    env e;

    address anyUsr; address anyUsr2;
    require anyUsr != e.msg.sender || anyUsr2 != spender;

    mathint allowanceOtherBefore = allowance(anyUsr, anyUsr2);

    approve(e, spender, value);

    mathint allowanceSenderSpenderAfter = allowance(e.msg.sender, spender);
    mathint allowanceOtherAfter = allowance(anyUsr, anyUsr2);

    assert allowanceSenderSpenderAfter == to_mathint(value), "Assert 1";
    assert allowanceOtherAfter == allowanceOtherBefore, "Assert 2";
}

// Verify revert rules on approve
rule approve_revert(address spender, uint256 value) {
    env e;

    approve@withrevert(e, spender, value);

    bool revert1 = e.msg.value > 0;

    assert lastReverted <=> revert1, "Revert rules failed";
}

// Verify correct storage changes for non reverting mint
rule mint(address to, uint256 value) {
    env e;

    requireInvariant balanceSum_equals_totalSupply();

    address other;
    require other != to;
    address anyUsr; address anyUsr2;

    bool senderSameAsTo = e.msg.sender == to;

    mathint totalSupplyBefore = totalSupply();
    mathint balanceOfToBefore = balanceOf(to);
    mathint balanceOfOtherBefore = balanceOf(other);

    mint(e, to, value);

    mathint totalSupplyAfter = totalSupply();
    mathint balanceOfToAfter = balanceOf(to);
    mathint balanceOfOtherAfter = balanceOf(other);

    assert totalSupplyAfter == totalSupplyBefore + value, "Assert 1";
    assert balanceOfToAfter == balanceOfToBefore + value, "Assert 2";
    assert balanceOfOtherAfter == balanceOfOtherBefore, "Assert 3";
}

// Verify revert rules on mint
rule mint_revert(address to, uint256 value) {
    env e;

    // Save the totalSupply and sender balance before minting
    mathint totalSupply = totalSupply();
    mathint wardsSender = wards(e.msg.sender);

    mint@withrevert(e, to, value);

    bool revert1 = e.msg.value > 0;
    bool revert2 = wardsSender != 1;
    bool revert3 = totalSupply + value > max_uint256;
    bool revert4 = to == 0 || to == currentContract;

    assert lastReverted <=> revert1 || revert2 || revert3 || revert4, "Revert rules failed";
}

// Verify correct storage changes for non reverting burn
rule burn(address from, uint256 value) {
    env e;

    requireInvariant balanceSum_equals_totalSupply();

    address other;
    require other != from;
    address anyUsr; address anyUsr2;
    require anyUsr != from || anyUsr2 != e.msg.sender;

    mathint totalSupplyBefore = totalSupply();
    mathint balanceOfFromBefore = balanceOf(from);
    mathint balanceOfOtherBefore = balanceOf(other);
    mathint allowanceFromSenderBefore = allowance(from, e.msg.sender);
    mathint allowanceOtherBefore = allowance(anyUsr, anyUsr2);

    burn(e, from, value);

    mathint totalSupplyAfter = totalSupply();
    mathint balanceOfSenderAfter = balanceOf(e.msg.sender);
    mathint balanceOfFromAfter = balanceOf(from);
    mathint balanceOfOtherAfter = balanceOf(other);
    mathint allowanceFromSenderAfter = allowance(from, e.msg.sender);
    mathint allowanceOtherAfter = allowance(anyUsr, anyUsr2);

    assert totalSupplyAfter == totalSupplyBefore - value, "Assert 1";
    assert balanceOfFromAfter == balanceOfFromBefore - value, "Assert 2";
    assert balanceOfOtherAfter == balanceOfOtherBefore, "Assert 3";
    assert e.msg.sender != from && allowanceFromSenderBefore != max_uint256 => allowanceFromSenderAfter == allowanceFromSenderBefore - value, "Assert 4";
    assert e.msg.sender == from => allowanceFromSenderAfter == allowanceFromSenderBefore, "Assert 5";
    assert allowanceFromSenderBefore == max_uint256 => allowanceFromSenderAfter == allowanceFromSenderBefore, "Assert 6";
    assert allowanceOtherAfter == allowanceOtherBefore, "Assert 7";
}

// Verify revert rules on burn
rule burn_revert(address from, uint256 value) {
    env e;

    mathint balanceOfFrom = balanceOf(from);
    mathint allowanceFromSender = allowance(from, e.msg.sender);

    burn@withrevert(e, from, value);

    bool revert1 = e.msg.value > 0;
    bool revert2 = balanceOfFrom < to_mathint(value);
    bool revert3 = from != e.msg.sender && allowanceFromSender < to_mathint(value);

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}

// Verify correct storage changes for non reverting permit
rule permitVRS(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) {
    env e;

    address anyUsr; address anyUsr2;
    require anyUsr != owner || anyUsr2 != spender;
    address other;
    require other != owner;

    mathint allowanceOtherBefore = allowance(anyUsr, anyUsr2);
    mathint noncesOwnerBefore = nonces(owner);
    mathint noncesOtherBefore = nonces(other);

    permit(e, owner, spender, value, deadline, v, r, s);

    mathint allowanceOwnerSpenderAfter = allowance(owner, spender);
    mathint allowanceOtherAfter = allowance(anyUsr, anyUsr2);
    mathint noncesOwnerAfter = nonces(owner);
    mathint noncesOtherAfter = nonces(other);

    assert allowanceOwnerSpenderAfter == to_mathint(value), "Assert 1";
    assert allowanceOtherAfter == allowanceOtherBefore, "Assert 2";
    assert noncesOwnerBefore < max_uint256 => noncesOwnerAfter == noncesOwnerBefore + 1, "Assert 3";
    assert noncesOwnerBefore == max_uint256 => noncesOwnerAfter == 0, "Assert 4";
    assert noncesOtherAfter == noncesOtherBefore, "Assert 5";
}

// Verify revert rules on permit
rule permitVRS_revert(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) {
    env e;

    bytes32 digest = aux.computeDigestForToken(
                        DOMAIN_SEPARATOR(),
                        PERMIT_TYPEHASH(),
                        owner,
                        spender,
                        value,
                        nonces(owner),
                        deadline
                    );
    address ownerRecover = aux.call_ecrecover(digest, v, r, s);
    bytes32 returnedSig = owner == signer ? signer.isValidSignature(e, digest, aux.VRSToSignature(v, r, s)) : to_bytes32(0);

    permit@withrevert(e, owner, spender, value, deadline, v, r, s);

    bool revert1 = e.msg.value > 0;
    bool revert2 = e.block.timestamp > deadline;
    bool revert3 = owner == 0;
    bool revert4 = owner != ownerRecover && returnedSig != to_bytes32(0x1626ba7e00000000000000000000000000000000000000000000000000000000);

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4, "Revert rules failed";
}

// Verify correct storage changes for non reverting permit
rule permitSignature(address owner, address spender, uint256 value, uint256 deadline, bytes signature) {
    env e;

    address anyUsr; address anyUsr2;
    require anyUsr != owner || anyUsr2 != spender;
    address other;
    require other != owner;

    mathint allowanceOtherBefore = allowance(anyUsr, anyUsr2);
    mathint noncesOwnerBefore = nonces(owner);
    mathint noncesOtherBefore = nonces(other);

    permit(e, owner, spender, value, deadline, signature);

    mathint allowanceOwnerSpenderAfter = allowance(owner, spender);
    mathint allowanceOtherAfter = allowance(anyUsr, anyUsr2);
    mathint noncesOwnerAfter = nonces(owner);
    mathint noncesOtherAfter = nonces(other);

    assert allowanceOwnerSpenderAfter == to_mathint(value), "Assert 1";
    assert allowanceOtherAfter == allowanceOtherBefore, "Assert 2";
    assert noncesOwnerBefore < max_uint256 => noncesOwnerAfter == noncesOwnerBefore + 1, "Assert 3";
    assert noncesOwnerBefore == max_uint256 => noncesOwnerAfter == 0, "Assert 4";
    assert noncesOtherAfter == noncesOtherBefore, "Assert 5";
}

// Verify revert rules on permit
rule permitSignature_revert(address owner, address spender, uint256 value, uint256 deadline, bytes signature) {
    env e;

    bytes32 digest = aux.computeDigestForToken(
                        DOMAIN_SEPARATOR(),
                        PERMIT_TYPEHASH(),
                        owner,
                        spender,
                        value,
                        nonces(owner),
                        deadline
                    );
    uint8 v; bytes32 r; bytes32 s;
    v, r, s = aux.signatureToVRS(signature);
    address null_address = 0;
    address ownerRecover = aux.size(signature) == 65 ? aux.call_ecrecover(digest, v, r, s) : null_address;
    bytes32 returnedSig = owner == signer ? signer.isValidSignature(e, digest, signature) : to_bytes32(0);

    permit@withrevert(e, owner, spender, value, deadline, signature);

    bool revert1 = e.msg.value > 0;
    bool revert2 = e.block.timestamp > deadline;
    bool revert3 = owner == 0;
    bool revert4 = owner != ownerRecover && returnedSig != to_bytes32(0x1626ba7e00000000000000000000000000000000000000000000000000000000);

    assert lastReverted <=> revert1 || revert2 || revert3 ||
                            revert4, "Revert rules failed";
}
