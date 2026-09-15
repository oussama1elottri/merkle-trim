// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * FLCheckpoint
 *
 * On-chain counterpart to VerifiableRobustStrategy's in-memory ledger.
 * Minimal dispute mechanism with succinct 32-byte Merkle root checkpoints.
 *
 * Design correspondence to the Python side:
 *   - roots[round]      ↔ self.ledger[round]["root"]
 *   - _merkleRoot()      ↔ VerifiableRobustStrategy._merkle_root()
 *     (same algorithm: hash each leaf once, then pairwise-combine,
 *      duplicating the last leaf if the layer is odd — must match
 *      exactly for a challenge to ever correctly detect fraud)
 *   - CHALLENGE_WINDOW   ↔ Task 4's optimistic-rollup challenge window
 */
contract FLCheckpoint {
    address public immutable aggregator;
    uint256 public constant CHALLENGE_WINDOW = 1 hours;

    mapping(uint256 => bytes32) public roots;      // round => posted Merkle root
    mapping(uint256 => uint256) public postedAt;   // round => timestamp of posting
    mapping(uint256 => bool)    public disputed;   // round => successfully challenged

    event RootPosted(uint256 indexed round, bytes32 root, uint256 timestamp);
    event ChallengeSucceeded(uint256 indexed round, address indexed challenger, bytes32 claimedRoot, bytes32 recomputedRoot);

    constructor() {
        aggregator = msg.sender;
    }

    // ── Honest path: aggregator posts this round's checkpoint ──────────────
    function postRoot(uint256 round, bytes32 root) external {
        require(msg.sender == aggregator, "only aggregator can post");
        require(roots[round] == bytes32(0), "round already posted");

        roots[round] = root;
        postedAt[round] = block.timestamp;

        emit RootPosted(round, root, block.timestamp);
    }

    // ── Dispute path: ANYONE can recompute the root from the full,
    //    publicly-revealed set of commitments and challenge a mismatch ─────
    function challenge(uint256 round, bytes32[] calldata allCommitments) external {
        require(roots[round] != bytes32(0), "round not posted");
        require(!disputed[round], "round already disputed");
        require(
            block.timestamp <= postedAt[round] + CHALLENGE_WINDOW,
            "challenge window closed"
        );

        bytes32 recomputed = _merkleRoot(allCommitments);
        require(recomputed != roots[round], "recomputed root matches - no fraud found");

        disputed[round] = true;
        emit ChallengeSucceeded(round, msg.sender, roots[round], recomputed);
    }

    // ── View helper: is this round safely finalized? ────────────────────────
    function isFinalized(uint256 round) external view returns (bool) {
        return
            roots[round] != bytes32(0) &&
            !disputed[round] &&
            block.timestamp > postedAt[round] + CHALLENGE_WINDOW;
    }

    // ── Public helper: recompute Merkle root for verification ─────────────────
    function computeRoot(bytes32[] calldata commitments) external pure returns (bytes32) {
        return _merkleRoot(commitments);
    }


    // ── Merkle root — must exactly mirror VerifiableRobustStrategy._merkle_root ──
    function _merkleRoot(bytes32[] memory commitments) internal pure returns (bytes32) {
        uint256 n = commitments.length;
        if (n == 0) {
            return bytes32(0);
        }

        // Step 1: hash each leaf once — matches Python's
        // `layer = [hashlib.sha256(leaf).digest() for leaf in leaves]`
        bytes32[] memory layer = new bytes32[](n);
        for (uint256 i = 0; i < n; i++) {
            layer[i] = sha256(abi.encodePacked(commitments[i]));
        }

        // Step 2: pairwise-combine until one root remains, duplicating the
        // last element when the layer is odd — matches Python's
        // `if len(layer) % 2 == 1: layer.append(layer[-1])`
        while (layer.length > 1) {
            uint256 len = layer.length;
            uint256 nextLen = (len + 1) / 2;
            bytes32[] memory next = new bytes32[](nextLen);

            for (uint256 i = 0; i < len; i += 2) {
                if (i + 1 < len) {
                    next[i / 2] = sha256(abi.encodePacked(layer[i], layer[i + 1]));
                } else {
                    next[i / 2] = sha256(abi.encodePacked(layer[i], layer[i]));
                }
            }
            layer = next;
        }

        return layer[0];
    }
}
