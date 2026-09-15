import { network } from "hardhat";
import * as fs from "fs";
import * as path from "path";

async function main() {
  const testDataPath = process.env.PARITY_TEST_FILE || path.join(process.cwd(), "merkle_parity_test.json");

  if (!fs.existsSync(testDataPath)) {
    console.error(`[ERROR] Test vector file not found at: ${testDataPath}`);
    process.exit(1);
  }

  const testCases = JSON.parse(fs.readFileSync(testDataPath, "utf-8"));
  const { viem } = await network.create();

  const checkpoint = await viem.deployContract("FLCheckpoint");

  let allPassed = true;

  for (const testCase of testCases) {
    const { name, commitments, expectedRoot } = testCase;
    const evmRoot = await checkpoint.read.computeRoot([commitments]);

    if (evmRoot.toLowerCase() === expectedRoot.toLowerCase()) {
      console.log(`[PASS] ${name}: EVM root matches Python root (${evmRoot})`);
    } else {
      console.error(`[FAIL] ${name}: EVM root (${evmRoot}) != Python root (${expectedRoot})`);
      allPassed = false;
    }
  }

  if (!allPassed) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
