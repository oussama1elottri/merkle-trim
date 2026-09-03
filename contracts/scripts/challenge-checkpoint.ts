import { network } from "hardhat";

const { viem, networkName } = await network.create();
const client = await viem.getPublicClient();

const CONTRACT_ADDRESS = "0x6beb9a47588ca99f125cb7debc6d052921dbe038";
console.log(`Connecting to FLCheckpoint on ${networkName}...`);
const checkpoint = await viem.getContractAt("FLCheckpoint", CONTRACT_ADDRESS);

// ── Raw commitment bytes — must match exactly what Python used ──────────────
// A = bytes.fromhex("aa"*32), B = bytes.fromhex("bb"*32), C = bytes.fromhex("cc"*32)
const A = `0x${"aa".repeat(32)}` as `0x${string}`;
const B = `0x${"bb".repeat(32)}` as `0x${string}`;
const C = `0x${"cc".repeat(32)}` as `0x${string}`;

// ── Step 1: aggregator posts a DISHONEST root (computed from A+B only) ──────

const ROUND = 5;
const dishonestRoot = "0xbb88ddaa45adc3afbf0438a0f9f92741af05647fb9e75c19889ae1265a74ce70";

console.log(`\nStep 1 — posting DISHONEST root for round ${ROUND}...`);
console.log(`  root: ${dishonestRoot} (computed from A+B only, C dropped)`);

const postTxHash = await checkpoint.write.postRoot([BigInt(ROUND), dishonestRoot as `0x${string}`]);
const postReceipt = await client.waitForTransactionReceipt({ hash: postTxHash });

console.log(`  Confirmed in block: ${postReceipt.blockNumber}`);
console.log(`  Gas used: ${postReceipt.gasUsed}`);

// ── Step 2: challenger disputes with the FULL honest commitment set ──────────
// Contract recomputes merkleRoot([A,B,C]) → 0x01df37ab...
// That ≠ posted 0xbb88ddaa... → ChallengeSucceeded event fires
console.log(`\nStep 2 — challenging round ${ROUND} with honest full set [A, B, C]...`);

const challengeTxHash = await checkpoint.write.challenge([BigInt(ROUND), [A, B, C]]);
const challengeReceipt = await client.waitForTransactionReceipt({ hash: challengeTxHash });

console.log(`  Confirmed in block: ${challengeReceipt.blockNumber}`);
console.log(`  Gas used: ${challengeReceipt.gasUsed}`);
console.log(`\n[SUCCESS] ChallengeSucceeded — fraud caught on real testnet.`);
console.log(`  Verify on explorer: https://moksha.vanascan.io/tx/${challengeTxHash}`);