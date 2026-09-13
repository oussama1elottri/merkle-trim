# MerkleTrim: Verifiable and Byzantine-Robust Federated Learning Framework

A lightweight, hardware-free verification layer for federated learning, combining
commit-reveal integrity checks, coordinate-wise trimmed mean aggregation, and an
on-chain Merkle checkpoint with an optimistic fraud-dispute mechanism.

Full technical writeup — problem statement, design, and empirical results — is in
[`REPORT.md`](./REPORT.md).

---

## Repository Structure

```
merkle-trim/            Root Directory
├── fl-engine/          Python FL engine (Flower 1.23+)
│   ├── fl_engine/      Core Python package (client, server, strategy, task)
│   └── scripts/        Benchmarking scripts & parity tests
│       ├── requirements.txt
│       ├── test_merkle_verification.py   Python/Solidity Merkle parity check
│       ├── benchmark_overhead.py         On-chain payload & compute overhead
│       └── benchmark_robustness.py       Robustness-under-attack damage curve
│
└── contracts/          Smart contract workspace (Hardhat 3)
    ├── contracts/      FLCheckpoint.sol & unit tests
    └── scripts/        Deployment & challenge scripts
        ├── deploy-checkpoint.ts
        ├── post-checkpoint.ts
        └── challenge-checkpoint.ts
```

---

## Quickstart

### 1. Python environment

```bash
python3 -m venv fl-env
source fl-env/bin/activate
pip install -r fl-engine/scripts/requirements.txt
```

### 2. Run the federated learning simulation

```bash
cd fl-engine
flwr run . --run-config "beta=0.2 malicious-fraction=0.2"
```

### 3. Run the smart contract test suite

```bash
cd contracts
npx hardhat test
```

### 4. Run the cross-language Merkle parity check

```bash
python3 fl-engine/scripts/test_merkle_verification.py
```

---

## Deployment & Testnet Guide

### Deployed contract

- **Network:** Vana Moksha Testnet (Chain ID 14800)
- **Contract address:** [`0x6beb9a47588ca99f125cb7debc6d052921dbe038`](https://moksha.vanascan.io/address/0x6beb9a47588ca99f125cb7debc6d052921dbe038)
- **RPC:** `https://rpc.moksha.vana.org`

### Deploy and interact

```bash
cd contracts

# Deploy
npx hardhat run scripts/deploy-checkpoint.ts --build-profile production --network moksha

# Post a Merkle root checkpoint
npx hardhat run scripts/post-checkpoint.ts --build-profile production --network moksha

# Trigger a fraud-proof dispute
npx hardhat run scripts/challenge-checkpoint.ts --build-profile production --network moksha
```

Both `postRoot` and `challenge` were confirmed on-chain against real Moksha
transactions — gas costs and block numbers are recorded in Section 3 of
[`REPORT.md`](./REPORT.md).

---

## License

MIT — see [LICENSE](./LICENSE).
