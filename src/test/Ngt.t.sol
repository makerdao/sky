// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.16;

import "dss-test/DssTest.sol";

import { Ngt, IERC1271 } from "../Ngt.sol";

contract MockMultisig is IERC1271 {
    address public signer1;
    address public signer2;

    constructor(address signer1_, address signer2_) {
        signer1 = signer1_;
        signer2 = signer2_;
    }

    function isValidSignature(bytes32 digest, bytes memory signature) external view returns (bytes4 sig) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        if (signer1 == ecrecover(digest, v, r, s)) {
            assembly {
                r := mload(add(signature, 0x80))
                s := mload(add(signature, 0xA0))
                v := byte(0, mload(add(signature, 0xC0)))
            }
            if (signer2 == ecrecover(digest, v, r, s)) {
                sig = IERC1271.isValidSignature.selector;
            }
        }
    }
}

contract NgtTest is DssTest {
    Ngt ngt;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function setUp() public {
        vm.expectEmit(true, true, true, true);
        emit Rely(address(this));
        ngt = new Ngt();
    }

    function testAuth() public {
        checkAuth(address(ngt), "Ngt");
    }

    function invariantMetadata() public {
        assertEq(ngt.name(), "NstDAO Governance Token");
        assertEq(ngt.symbol(), "NGT");
        assertEq(ngt.version(), "1");
        assertEq(ngt.decimals(), 18);
    }

    function testMint() public {
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), address(0xBEEF), 1e18);
        ngt.mint(address(0xBEEF), 1e18);

        assertEq(ngt.totalSupply(), 1e18);
        assertEq(ngt.balanceOf(address(0xBEEF)), 1e18);
    }

    function testMintBadAddress() public {
        vm.expectRevert("Ngt/invalid-address");
        ngt.mint(address(0), 1e18);
        vm.expectRevert("Ngt/invalid-address");
        ngt.mint(address(ngt), 1e18);
    }

    function testBurn() public {
        ngt.mint(address(0xBEEF), 1e18);

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0xBEEF), address(0), 0.9e18);
        vm.prank(address(0xBEEF));
        ngt.burn(address(0xBEEF), 0.9e18);

        assertEq(ngt.totalSupply(), 1e18 - 0.9e18);
        assertEq(ngt.balanceOf(address(0xBEEF)), 0.1e18);
    }

    function testBurnDifferentFrom() public {
        ngt.mint(address(0xBEEF), 1e18);

        assertEq(ngt.allowance(address(0xBEEF), address(this)), 0);
        vm.prank(address(0xBEEF));
        ngt.approve(address(this), 0.4e18);
        assertEq(ngt.allowance(address(0xBEEF), address(this)), 0.4e18);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0xBEEF), address(0), 0.4e18);
        ngt.burn(address(0xBEEF), 0.4e18);
        assertEq(ngt.allowance(address(0xBEEF), address(this)), 0);

        assertEq(ngt.totalSupply(), 1e18 - 0.4e18);
        assertEq(ngt.balanceOf(address(0xBEEF)), 0.6e18);

        vm.prank(address(0xBEEF));
        ngt.approve(address(this), type(uint256).max);
        assertEq(ngt.allowance(address(0xBEEF), address(this)), type(uint256).max);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0xBEEF), address(0), 0.4e18);
        ngt.burn(address(0xBEEF), 0.4e18);
        assertEq(ngt.allowance(address(0xBEEF), address(this)), type(uint256).max);

        assertEq(ngt.totalSupply(), 0.6e18 - 0.4e18);
        assertEq(ngt.balanceOf(address(0xBEEF)), 0.2e18);
    }

    function testApprove() public {
        vm.expectEmit(true, true, true, true);
        emit Approval(address(this), address(0xBEEF), 1e18);
        assertTrue(ngt.approve(address(0xBEEF), 1e18));

        assertEq(ngt.allowance(address(this), address(0xBEEF)), 1e18);
    }

    function testIncreaseAllowance() public {
        vm.expectEmit(true, true, true, true);
        emit Approval(address(this), address(0xBEEF), 1e18);
        assertTrue(ngt.increaseAllowance(address(0xBEEF), 1e18));

        assertEq(ngt.allowance(address(this), address(0xBEEF)), 1e18);
    }

    function testDecreaseAllowance() public {
        assertTrue(ngt.increaseAllowance(address(0xBEEF), 3e18));
        vm.expectEmit(true, true, true, true);
        emit Approval(address(this), address(0xBEEF), 2e18);
        assertTrue(ngt.decreaseAllowance(address(0xBEEF), 1e18));

        assertEq(ngt.allowance(address(this), address(0xBEEF)), 2e18);
    }

    function testDecreaseAllowanceInsufficientBalance() public {
        assertTrue(ngt.increaseAllowance(address(0xBEEF), 1e18));
        vm.expectRevert("Ngt/insufficient-allowance");
        ngt.decreaseAllowance(address(0xBEEF), 2e18);
    }

    function testTransfer() public {
        ngt.mint(address(this), 1e18);

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(this), address(0xBEEF), 1e18);
        assertTrue(ngt.transfer(address(0xBEEF), 1e18));
        assertEq(ngt.totalSupply(), 1e18);

        assertEq(ngt.balanceOf(address(this)), 0);
        assertEq(ngt.balanceOf(address(0xBEEF)), 1e18);
    }

    function testTransferBadAddress() public {
        ngt.mint(address(this), 1e18);

        vm.expectRevert("Ngt/invalid-address");
        ngt.transfer(address(0), 1e18);
        vm.expectRevert("Ngt/invalid-address");
        ngt.transfer(address(ngt), 1e18);
    }

    function testTransferFrom() public {
        address from = address(0xABCD);

        ngt.mint(from, 1e18);

        vm.prank(from);
        ngt.approve(address(this), 1e18);

        vm.expectEmit(true, true, true, true);
        emit Transfer(from, address(0xBEEF), 1e18);
        assertTrue(ngt.transferFrom(from, address(0xBEEF), 1e18));
        assertEq(ngt.totalSupply(), 1e18);

        assertEq(ngt.allowance(from, address(this)), 0);

        assertEq(ngt.balanceOf(from), 0);
        assertEq(ngt.balanceOf(address(0xBEEF)), 1e18);
    }

    function testTransferFromBadAddress() public {
        ngt.mint(address(this), 1e18);
        
        vm.expectRevert("Ngt/invalid-address");
        ngt.transferFrom(address(this), address(0), 1e18);
        vm.expectRevert("Ngt/invalid-address");
        ngt.transferFrom(address(this), address(ngt), 1e18);
    }

    function testInfiniteApproveTransferFrom() public {
        address from = address(0xABCD);

        ngt.mint(from, 1e18);

        vm.prank(from);
        vm.expectEmit(true, true, true, true);
        emit Approval(from, address(this), type(uint256).max);
        ngt.approve(address(this), type(uint256).max);

        vm.expectEmit(true, true, true, true);
        emit Transfer(from, address(0xBEEF), 1e18);
        assertTrue(ngt.transferFrom(from, address(0xBEEF), 1e18));
        assertEq(ngt.totalSupply(), 1e18);

        assertEq(ngt.allowance(from, address(this)), type(uint256).max);

        assertEq(ngt.balanceOf(from), 0);
        assertEq(ngt.balanceOf(address(0xBEEF)), 1e18);
    }

    function testPermit() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    ngt.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        vm.expectEmit(true, true, true, true);
        emit Approval(owner, address(0xCAFE), 1e18);
        ngt.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);

        assertEq(ngt.allowance(owner, address(0xCAFE)), 1e18);
        assertEq(ngt.nonces(owner), 1);
    }

    function testPermitContract() public {
        uint256 privateKey1 = 0xBEEF;
        address signer1 = vm.addr(privateKey1);
        uint256 privateKey2 = 0xBEEE;
        address signer2 = vm.addr(privateKey2);

        address mockMultisig = address(new MockMultisig(signer1, signer2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            uint256(privateKey1),
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    ngt.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, mockMultisig, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(
            uint256(privateKey2),
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    ngt.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, mockMultisig, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        bytes memory signature = abi.encode(r, s, bytes32(uint256(v) << 248), r2, s2, bytes32(uint256(v2) << 248));
        vm.expectEmit(true, true, true, true);
        emit Approval(mockMultisig, address(0xCAFE), 1e18);
        ngt.permit(mockMultisig, address(0xCAFE), 1e18, block.timestamp, signature);

        assertEq(ngt.allowance(mockMultisig, address(0xCAFE)), 1e18);
        assertEq(ngt.nonces(mockMultisig), 1);
    }

    function testPermitContractInvalidSignature() public {
        uint256 privateKey1 = 0xBEEF;
        address signer1 = vm.addr(privateKey1);
        uint256 privateKey2 = 0xBEEE;
        address signer2 = vm.addr(privateKey2);

        address mockMultisig = address(new MockMultisig(signer1, signer2));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            uint256(privateKey1),
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    ngt.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, mockMultisig, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(
            uint256(0xCEEE),
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    ngt.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, mockMultisig, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        bytes memory signature = abi.encode(r, s, bytes32(uint256(v) << 248), r2, s2, bytes32(uint256(v2) << 248));
        vm.expectRevert("Ngt/invalid-permit");
        ngt.permit(mockMultisig, address(0xCAFE), 1e18, block.timestamp, signature);
    }

    function testTransferInsufficientBalance() public {
        ngt.mint(address(this), 0.9e18);
        vm.expectRevert("Ngt/insufficient-balance");
        ngt.transfer(address(0xBEEF), 1e18);
    }

    function testTransferFromInsufficientAllowance() public {
        address from = address(0xABCD);

        ngt.mint(from, 1e18);

        vm.prank(from);
        ngt.approve(address(this), 0.9e18);

        vm.expectRevert("Ngt/insufficient-allowance");
        ngt.transferFrom(from, address(0xBEEF), 1e18);
    }

    function testTransferFromInsufficientBalance() public {
        address from = address(0xABCD);

        ngt.mint(from, 0.9e18);

        vm.prank(from);
        ngt.approve(address(this), 1e18);

        vm.expectRevert("Ngt/insufficient-balance");
        ngt.transferFrom(from, address(0xBEEF), 1e18);
    }

    function testPermitBadNonce() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    ngt.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 1, block.timestamp))
                )
            )
        );

        vm.expectRevert("Ngt/invalid-permit");
        ngt.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testPermitBadDeadline() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    ngt.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        vm.expectRevert("Ngt/invalid-permit");
        ngt.permit(owner, address(0xCAFE), 1e18, block.timestamp + 1, v, r, s);
    }

    function testPermitPastDeadline() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);
        uint256 deadline = block.timestamp;

        bytes32 domain_separator = ngt.DOMAIN_SEPARATOR();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domain_separator,
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, deadline))
                )
            )
        );

        vm.warp(deadline + 1);

        vm.expectRevert("Ngt/permit-expired");
        ngt.permit(owner, address(0xCAFE), 1e18, deadline, v, r, s);
    }

    function testPermitOwnerZero() public {
        vm.expectRevert("Ngt/invalid-owner");
        ngt.permit(address(0), address(0xCAFE), 1e18, block.timestamp, 28, bytes32(0), bytes32(0));
    }

    function testPermitReplay() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    ngt.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(0xCAFE), 1e18, 0, block.timestamp))
                )
            )
        );

        ngt.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
        vm.expectRevert("Ngt/invalid-permit");
        ngt.permit(owner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }

    function testMint(address to, uint256 amount) public {
        if (to != address(0) && to != address(ngt)) {
            vm.expectEmit(true, true, true, true);
            emit Transfer(address(0), to, amount);
        } else {
            vm.expectRevert("Ngt/invalid-address");
        }
        ngt.mint(to, amount);

        if (to != address(0) && to != address(ngt)) {
            assertEq(ngt.totalSupply(), amount);
            assertEq(ngt.balanceOf(to), amount);
        }
    }

    function testBurn(
        address from,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        if (from == address(0) || from == address(ngt)) return;

        burnAmount = bound(burnAmount, 0, mintAmount);

        ngt.mint(from, mintAmount);

        vm.expectEmit(true, true, true, true);
        emit Transfer(from, address(0), burnAmount);
        vm.prank(from);
        ngt.burn(from, burnAmount);

        assertEq(ngt.totalSupply(), mintAmount - burnAmount);
        assertEq(ngt.balanceOf(from), mintAmount - burnAmount);
    }

    function testApprove(address to, uint256 amount) public {
        vm.expectEmit(true, true, true, true);
        emit Approval(address(this), to, amount);
        assertTrue(ngt.approve(to, amount));

        assertEq(ngt.allowance(address(this), to), amount);
    }

    function testTransfer(address to, uint256 amount) public {
        if (to == address(0) || to == address(ngt)) return;

        ngt.mint(address(this), amount);

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(this), to, amount);
        assertTrue(ngt.transfer(to, amount));
        assertEq(ngt.totalSupply(), amount);

        if (address(this) == to) {
            assertEq(ngt.balanceOf(address(this)), amount);
        } else {
            assertEq(ngt.balanceOf(address(this)), 0);
            assertEq(ngt.balanceOf(to), amount);
        }
    }

    function testTransferFrom(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        if (to == address(0) || to == address(ngt)) return;

        amount = bound(amount, 0, approval);

        address from = address(0xABCD);

        ngt.mint(from, amount);

        vm.prank(from);
        ngt.approve(address(this), approval);

        vm.expectEmit(true, true, true, true);
        emit Transfer(from, to, amount);
        assertTrue(ngt.transferFrom(from, to, amount));
        assertEq(ngt.totalSupply(), amount);

        uint256 app = from == address(this) || approval == type(uint256).max ? approval : approval - amount;
        assertEq(ngt.allowance(from, address(this)), app);

        if (from == to) {
            assertEq(ngt.balanceOf(from), amount);
        } else  {
            assertEq(ngt.balanceOf(from), 0);
            assertEq(ngt.balanceOf(to), amount);
        }
    }

    function testPermit(
        uint248 privKey,
        address to,
        uint256 amount,
        uint256 deadline
    ) public {
        uint256 privateKey = privKey;
        if (deadline < block.timestamp) deadline = block.timestamp;
        if (privateKey == 0) privateKey = 1;

        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    ngt.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
                )
            )
        );

        vm.expectEmit(true, true, true, true);
        emit Approval(owner, to, amount);
        ngt.permit(owner, to, amount, deadline, v, r, s);

        assertEq(ngt.allowance(owner, to), amount);
        assertEq(ngt.nonces(owner), 1);
    }

    function testBurnInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        if (to == address(0) || to == address(ngt)) return;

        if (mintAmount == type(uint256).max) mintAmount -= 1;
        burnAmount = bound(burnAmount, mintAmount + 1, type(uint256).max);

        ngt.mint(to, mintAmount);
        vm.expectRevert("Ngt/insufficient-balance");
        ngt.burn(to, burnAmount);
    }

    function testTransferInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 sendAmount
    ) public {
        if (to == address(0) || to == address(ngt)) return;

        if (mintAmount == type(uint256).max) mintAmount -= 1;
        sendAmount = bound(sendAmount, mintAmount + 1, type(uint256).max);

        ngt.mint(address(this), mintAmount);
        vm.expectRevert("Ngt/insufficient-balance");
        ngt.transfer(to, sendAmount);
    }

    function testTransferFromInsufficientAllowance(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        if (to == address(0) || to == address(ngt)) return;

        if (approval == type(uint256).max) approval -= 1;
        amount = bound(amount, approval + 1, type(uint256).max);

        address from = address(0xABCD);

        ngt.mint(from, amount);

        vm.prank(from);
        ngt.approve(address(this), approval);

        vm.expectRevert("Ngt/insufficient-allowance");
        ngt.transferFrom(from, to, amount);
    }

    function testTransferFromInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 sendAmount
    ) public {
        if (to == address(0) || to == address(ngt)) return;

        if (mintAmount == type(uint256).max) mintAmount -= 1;
        sendAmount = bound(sendAmount, mintAmount + 1, type(uint256).max);

        address from = address(0xABCD);

        ngt.mint(from, mintAmount);

        vm.prank(from);
        ngt.approve(address(this), sendAmount);

        vm.expectRevert("Ngt/insufficient-balance");
        ngt.transferFrom(from, to, sendAmount);
    }

    function testPermitBadNonce(
        uint128 privateKey,
        address to,
        uint256 amount,
        uint256 deadline,
        uint256 nonce
    ) public {
        if (deadline < block.timestamp) deadline = block.timestamp;
        if (privateKey == 0) privateKey = 1;
        if (nonce == 0) nonce = 1;

        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    ngt.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, nonce, deadline))
                )
            )
        );

        vm.expectRevert("Ngt/invalid-permit");
        ngt.permit(owner, to, amount, deadline, v, r, s);
    }

    function testPermitBadDeadline(
        uint128 privateKey,
        address to,
        uint256 amount,
        uint256 deadline
    ) public {
        if (deadline == type(uint256).max) deadline -= 1;
        if (deadline < block.timestamp) deadline = block.timestamp;
        if (privateKey == 0) privateKey = 1;

        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    ngt.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
                )
            )
        );

        vm.expectRevert("Ngt/invalid-permit");
        ngt.permit(owner, to, amount, deadline + 1, v, r, s);
    }

    function testPermitPastDeadline(
        uint128 privateKey,
        address to,
        uint256 amount,
        uint256 deadline
    ) public {
        if (deadline == type(uint256).max) deadline -= 1;

        // private key cannot be 0 for secp256k1 pubkey generation
        if (privateKey == 0) privateKey = 1;

        address owner = vm.addr(privateKey);

        bytes32 domain_separator = ngt.DOMAIN_SEPARATOR();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domain_separator,
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
                )
            )
        );

        vm.warp(deadline + 1);

        vm.expectRevert("Ngt/permit-expired");
        ngt.permit(owner, to, amount, deadline, v, r, s);
    }

    function testPermitReplay(
        uint128 privateKey,
        address to,
        uint256 amount,
        uint256 deadline
    ) public {
        if (deadline < block.timestamp) deadline = block.timestamp;
        if (privateKey == 0) privateKey = 1;

        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    ngt.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, to, amount, 0, deadline))
                )
            )
        );

        ngt.permit(owner, to, amount, deadline, v, r, s);
        vm.expectRevert("Ngt/invalid-permit");
        ngt.permit(owner, to, amount, deadline, v, r, s);
    }
}
