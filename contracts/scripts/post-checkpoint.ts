import { network } from "hardhat";

const { viem, networkName } = await network.create();
const client = await viem.getPublicClient();

const CONTRACT_ADDRESS = "0x6beb9a47588ca99f125cb7debc6d052921dbe038";

console.log(`Connecting to FLCheckpoint on ${networkName}...`);

const checkpoint = await viem.getContractAt("FLCheckpoint", CONTRACT_ADDRESS);

const round = 3;
const root  = "0x420940ee1c7a73de80cfa2554efb4e6cec7ea745fed73108ccb06886054df8c6";

console.log(`Posting round ${round} with root ${root}...`);

const txHash = await checkpoint.write.postRoot([BigInt(round), root]);

console.log("Waiting for confirmation...");
const receipt = await client.waitForTransactionReceipt({ hash: txHash });

console.log("Confirmed in block:", receipt.blockNumber);
console.log("Gas used:", receipt.gasUsed.toString());