// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {FLCheckpoint} from "./FLCheckpoint.sol";

contract FLCheckpointTest is Test {
    FLCheckpoint checkpoint;

    function setUp() public {
        checkpoint = new FLCheckpoint();
    }

    // ── Test 1: Aggregator can post a root ─────────────────────────────────
    function test_PostRoot() public {
        bytes32 testRoot = keccak256("test_root");
        checkpoint.postRoot(1, testRoot);

        require(checkpoint.roots(1) == testRoot, "Root not set correctly");
        require(checkpoint.postedAt(1) > 0, "Timestamp not recorded");
    }

    // ── additional Test: Aggregator only can post a root ─────────────────────────────────
    function test_OnlyAggregatorCanPostRoot() public {
        bytes32 testRoot = keccak256("test_root");
        address notAggregator = address(0x123);
        vm.prank(notAggregator);
        vm.expectRevert("only aggregator can post");
        checkpoint.postRoot(1, testRoot);
    }

    // ── Test 2: Fraud Challenge Succeeded ──────────────────────────────────
    function test_ChallengeSucceeded() public {
        // 3 commitments (Odd count)
        bytes32[] memory commitments = new bytes32[](3);
        commitments[0] = sha256("commitment_A");
        commitments[1] = sha256("commitment_B");
        commitments[2] = sha256("commitment_C");

        // Post a FAKE root (fraud)
        bytes32 fakeRoot = keccak256("fake_fraudulent_root");
        checkpoint.postRoot(1, fakeRoot);

        // Challenge the fraudulent round
        checkpoint.challenge(1, commitments);

        // Verify the round is marked as disputed
        require(checkpoint.disputed(1) == true, "Round should be marked as disputed");
    }

    // ── Test 3: Challenge Fails when Root is Honest ────────────────────────
    function test_ChallengeFailsIfHonest() public {
        bytes32[] memory commitments = new bytes32[](3);
        commitments[0] = sha256("commitment_A");
        commitments[1] = sha256("commitment_B");
        commitments[2] = sha256("commitment_C");

        // Compute real root using Python/Solidity exact algorithm:
        // Leaves hashed once:
        bytes32 l0 = sha256(abi.encodePacked(commitments[0]));
        bytes32 l1 = sha256(abi.encodePacked(commitments[1]));
        bytes32 l2 = sha256(abi.encodePacked(commitments[2]));
        // Round 1 (Odd len=3 -> duplicate l2):
        bytes32 r0 = sha256(abi.encodePacked(l0, l1));
        bytes32 r1 = sha256(abi.encodePacked(l2, l2));
        // Round 2:
        bytes32 realRoot = sha256(abi.encodePacked(r0, r1));

        // Aggregator posts HONEST root
        checkpoint.postRoot(1, realRoot);

        // Expect revert when challenging an honest root
        vm.expectRevert();
        checkpoint.challenge(1, commitments);
    }
}
