import { network } from "hardhat";

const { viem, networkName } = await network.create();

const client = await viem.getPublicClient();

console.log(`Deploying FLCheckpoint to ${networkName}...`);

const checkpoint = await viem.deployContract("FLCheckpoint");

console.log("FLCheckpoint address:", checkpoint.address);

console.log("Deployment successful!");
