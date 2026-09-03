# MerkleTrim: Verifiable Robust Aggregation Engine

A Flower Strategy that defends federated aggregation against two distinct attack
types — tamper-after-commit and honest-commit-to-poisoned-data — using
commit-reveal verification and coordinate-wise trimmed mean aggregation, then
anchors each round's integrity with a 32-byte Merkle checkpoint suitable for
on-chain posting.

Full technical report — problem statement, mechanism design, and complete
benchmark results — is at [`../REPORT.md`](../REPORT.md).

## Setup

```bash
pip install .
```

## Running the Baseline

```bash
flwr run . --run-config "beta=0.2 malicious-fraction=0.2"
```

This runs 10 clients (2 simulated as attackers), applies commit-reveal
verification and trimmed mean aggregation each round, and prints a ledger of
per-round Merkle roots at the end.

To reproduce the full robustness sweep reported in `REPORT.md` (0%, 20%, 30%,
50% malicious fractions), vary `malicious-fraction` and `beta` in the command
above — see Section 3 of the report for the exact configurations used.

## Benchmark Scripts & Results

See [`scripts/`](./scripts) for the evaluation scripts and generated charts:
- `scripts/benchmark_overhead.py` $\rightarrow$ `scripts/benchmark_overhead.png` (Payload & compute time)
- `scripts/benchmark_robustness.py` $\rightarrow$ `scripts/benchmark_robustness.png` (Accuracy damage curve)
- `scripts/test_merkle_verification.py` (Cross-language Python/EVM parity test)

Full numerical tables and discussion are detailed in [`../REPORT.md`](../REPORT.md).

## Relationship to the on-chain component

This Baseline is fully self-contained and runs entirely off-chain — no network
connection or blockchain interaction is required to reproduce any result here.
A separate, independently-testable proof-of-concept (`contracts/`, a
Hardhat/Solidity project deployed to Vana's Moksha testnet) demonstrates that
the Merkle root this Strategy computes can be posted on-chain and disputed via
an optimistic fraud-proof mechanism. The two are connected manually — a
computed root is copied from this Strategy's output into the separate
on-chain script — not through any code-level integration.