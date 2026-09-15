# MerkleTrim: Verifiable and Byzantine-Robust Federated Learning Technical Report

## Section 1: Introduction and Problem Formulation

Federated Learning (FL) enables distributed entities (such as healthcare providers, financial institutions, and public agencies) to collaboratively train machine learning models without aggregating raw private data. However, traditional FL architectures rely on unverified trust assumptions: central aggregators can censor or tamper with client contributions, while malicious clients can submit poisoned updates. Existing mitigations introduce severe structural trade-offs: full on-chain logging imposes prohibitive $O(n)$ bandwidth overhead per round, whereas Trusted Execution Environments (TEEs) require specialized hardware, introduce vendor lock-in, and remain susceptible to side-channel exploits.

To address these challenges in hardware-constrained environments, this project proposes a lightweight, verifiable FL framework operating within strictly defined security boundaries:

- **Byzantine-Resilient Filtering:** The architecture integrates coordinate-wise $\beta$-trimmed mean aggregation to provide Byzantine fault tolerance against unbounded model poisoning attacks, under the assumption that $f/n < \beta$.
- **Anti-Frontrunning & Replay Protection:** To guarantee update freshness and prevent front-running or replay attacks by adversarial clients, a two-phase commit-reveal protocol bound by cryptographic nonces is enforced, where nonces prevent replay across rounds and the hiding property of the commitment phase prevents adaptive front-running.
- **Succinct On-Chain State Commitment:** Off-chain computational integrity is anchored on-chain via succinct 32-byte Merkle root state checkpoints, reducing routine storage overhead to $O(1)$.
- **Hardware-Free Execution Integrity:** Aggregator honesty is verified using an optimistic challenge window under a single-honest-verifier assumption, enabling any participant to cryptographically dispute fraudulent aggregation states without executing expensive machine learning matrix operations on-chain.

---

## Section 2: System Mechanism & Protocol Walkthrough

### 2.1 Commit-Reveal Protocol & Nonce Binding

The client trains the model locally on its private dataset. Rather than transmitting raw model updates un-hashed, the client generates a random cryptographic nonce and sends a SHA-256 commitment hash bound to the parameter payload, nonce, and current round number. In this prototype implementation, commitment hashing and payload transmission occur within the same message turn; in a multi-phase production network, this can be split across a fixed commit deadline followed by a reveal period to prevent adaptive front-running.

### 2.2 Verification & Trimmed Mean Aggregation

Upon receiving client submissions, the aggregator verifies each payload by recomputing its expected SHA-256 commitment hash and comparing it against the received commitment string. Any client update whose computed hash mismatches is immediately rejected (mitigating Type 1 tampering attacks). Verified parameter vectors are then aggregated using a coordinate-wise $\beta$-trimmed mean rule: at each coordinate in the weight vector, the highest and lowest $k = \lfloor\beta \cdot n\rfloor$ values across all clients are discarded before averaging the remaining elements. This operates entirely on individual weight values, not on client identities — the mechanism never determines which client is responsible for a trimmed value, only which values are statistical outliers at a given coordinate.

### 2.3 Succinct On-Chain Checkpoints & Fraud Dispute Engine

Following aggregation, the aggregator builds a binary SHA-256 Merkle tree over the set of verified client commitment hashes and posts only the resulting 32-byte Merkle root on-chain. To enforce aggregator honesty without expensive matrix math on-chain, any independent participant holding the complete, true set of client commitments can invoke the smart contract's `challenge()` function directly. The contract recomputes the Merkle root on-chain inside the EVM; a hash mismatch instantly flags the round as disputed and emits a `ChallengeSucceeded` event.

### 2.4 Trust Minimization & Data Availability Considerations

This mechanism removes trust from the verification step itself — a challenger's recomputation is checked independently by the EVM and cannot be falsified. Data availability — ensuring independent verifiers maintain access to the valid commitment set across training rounds — remains an open design challenge, discussed further in the limitations section.

---

## Section 3: Empirical Evaluation

### 3.1 Experimental Setup

Three separate evaluations were conducted. On-chain payload size and aggregation compute time (3.2) were measured on synthetic client data matched to the real deployed model's size, isolating these costs from Flower/Ray simulation overhead. Robustness under attack (3.3) used 10 real clients running sklearn logistic regression over 3 training rounds, comparing `VerifiableRobustStrategy` ($\beta = 0.2$) against undefended `FedAvg` ($\beta = 0.0$). Real testnet costs (3.4) were measured from actual transactions against the deployed `FLCheckpoint` contract on Vana's Moksha testnet.

### 3.2 On-Chain Payload and Compute Overhead

Model size confirmed from a real `flwr run`: 0.06 MB (60,000 bytes) per client.

**On-chain payload per round:**

| Clients | Naive full logging (bytes) | This design (bytes) | Reduction |
|---:|---:|---:|---:|
| 5   | 300,000    | 32 | 9,375×    |
| 20  | 1,200,000  | 32 | 37,500×   |
| 50  | 3,000,000  | 32 | 93,750×   |
| 100 | 6,000,000  | 32 | 187,500×  |
| 500 | 30,000,000 | 32 | 937,500×  |

**Aggregation compute time (median of 20 runs):**

| Clients | Plain mean (ms) | Trimmed mean (ms) | Merkle build (ms) |
|---:|---:|---:|---:|
| 5   | 0.0612 | 0.8444  | 0.0152 |
| 20  | 0.1939 | 1.9002  | 0.0504 |
| 50  | 0.4213 | 2.8442  | 0.1369 |
| 100 | 1.0066 | 6.4124  | 0.2431 |
| 500 | 9.5517 | 66.3443 | 1.3794 |

This design always posts exactly 32 bytes on-chain per round, regardless of client count — $O(1)$ versus the naive baseline's $O(n)$. Trimmed mean costs roughly 7× plain mean at 500 clients, and Merkle root construction remains sub-2ms even at that scale. The design's value is entirely in bandwidth reduction, not computational speed — even the largest measured overhead (66ms at 500 clients) is negligible against a real training round, which takes tens of seconds end to end.

### 3.3 Robustness Under Attack

See Section 3.3 discussion below — full setup, results table, and analysis.

**Setup:** 10 clients, sklearn logistic regression, 3 rounds. `VerifiableRobustStrategy` evaluated at $\alpha \in \{0.0, 0.20, 0.30, 0.50\}$; undefended `FedAvg` evaluated at $\alpha \in \{0.0, 0.20, 0.30, 0.40, 0.50\}$.

| Malicious Fraction ($\alpha$) | Strategy | Round 1 | Round 2 | Round 3 | Final Status |
|:---:|:---:|:---:|:---:|:---:|:---:|
| 0% (clean)¹ | `VerifiableRobust` | 0.6916 | 0.7343 | 0.7725 | Baseline |
| 0% (clean)¹ | Plain `FedAvg` | 0.6916 | 0.7343 | 0.7725 | Baseline |
| 20% | `VerifiableRobust` | 0.7107 | 0.7598 | 0.8048 | Stable |
| 20% | Plain `FedAvg` | 0.7517 | 0.3311 | 0.5988 | Degraded |
| 30% | `VerifiableRobust` | 0.7391 | 0.8187 | 0.8099 | Stable |
| 30% | Plain `FedAvg` | 0.7742 | 0.7205 | 0.7995 | Degraded² |
| 40% | Plain `FedAvg` | 0.7693 | 0.0988 | 0.0633 | Degraded |
| 50% | `VerifiableRobust` | 0.7449 | 0.3313 | 0.5510 | Collapsed |
| 50% | Plain `FedAvg` | 0.7241 | 0.7335 | 0.1946 | Degraded |

¹ Identical rows — no attack is present to differentiate the strategies at $\alpha = 0$.
² See discussion point 3 — part of a broader non-monotonic pattern in the undefended baseline.

**Discussion:**

**1. The undefended baseline is consistently vulnerable to poisoning, though inconsistently so.** At every tested fraction except 30%, plain FedAvg's final-round accuracy is substantially below the clean baseline (0.7725) — collapsing as low as 0.0633 at $\alpha = 0.40$. The 30% result is addressed in point 3.

**2. `VerifiableRobustStrategy` holds through $\alpha = 0.30$ — a fraction already exceeding $\beta$ — before failing at $\alpha = 0.50$.** With $\beta = 0.2$ and $n = 10$, $k = \lfloor 0.2 \times 10 \rfloor = 2$ clients are trimmed from each end regardless of true attacker count. At $\alpha = 0.30$ (3 attackers), only one poisoned update survives trimming, diluted across the aggregate with no measurable damage. At $\alpha = 0.50$ (5 attackers), three of five survive, crossing a majority-damage threshold and producing the observed oscillation (0.7449 → 0.3313 → 0.5510). This indicates a practical robustness margin extending somewhat beyond the strict bound $\alpha < \beta$; the precise boundary between 0.30 and 0.50 was not further isolated.

**3. The undefended baseline's results are non-monotonic in $\alpha$.** Final-round accuracy across 20/30/40/50% is 0.5988 / 0.7995 / 0.0633 / 0.1946. This is attributed to run-to-run variance at small client count — with $n=10$ and one run per configuration, outcomes depend heavily on which specific clients are selected as attackers. Seed-averaged repetition would be needed for a smoothed baseline curve. This does not affect the defended-strategy results in point 2, which show a consistent, mechanistically-explained pattern.

### 3.4 Real Testnet Gas Costs (Vana Moksha)

Contract: `FLCheckpoint.sol` — Address: `0x6beb9a47588ca99f125cb7debc6d052921dbe038`

| Operation | Gas used | Block | Notes |
|---|---:|---:|---|
| `postRoot()` — honest round 1 | 68,147 | 8,476,875 | Two new storage writes |
| `postRoot()` — dishonest round 5 | 68,147 | 8,516,967 | Consistent, predictable |
| `challenge()` — `ChallengeSucceeded` | 59,398 | 8,516,968 | One write + event emit |

Posting cost is perfectly consistent across both real transactions (68,147 gas both times), confirming predictable overhead. Challenging is cheaper than posting — it reads existing storage rather than writing new slots. Consecutive block numbers (8,516,967 → 8,516,968) confirm near-instant confirmation under normal Moksha conditions. The `ChallengeSucceeded` event is independently verifiable at [moksha.vanascan.io](https://moksha.vanascan.io/tx/0x63f4616869ab585895e6b39aef71fb93a132655ffe8254640581df755c25f29e).

---

## Section 4: Comparison versus TEE-Based Approaches

| Dimension | This design | TEE (e.g. Vana) |
|---|---|---|
| Trust assumption | Cryptographic math + statistical majority | Hardware chip manufacturer |
| Hardware requirement | None — any Python-capable device | SGX/TDX/TrustZone-capable CPU required |
| Catches Type 1 (tamper) | Yes — hash mismatch, client identified | Yes — attestation fails |
| Catches Type 2 (poisoning) | Statistical only; requires $f/n < \beta$ | Only if data provenance is also attested |
| Side-channel exposure | None | Real — documented SGX/TDX exploits exist |
| Per-round cost | $O(1)$ — 32 bytes on-chain | Higher — remote attestation overhead |
| Procurement constraint | None | Specific vetted hardware required |

**Where this design wins:** heterogeneous edge devices, and agencies operating under procurement rules that forbid proprietary secure hardware — the public-sector setting this project targets.

**Where TEE wins:** when every participant already has attestable hardware and end-to-end data provenance can be established from original collection through training — giving strong per-round integrity without depending on a malicious-fraction threshold.

---

## Section 5: Limitations

1. **Stealthy / backdoor poisoning** — an update deliberately calibrated to remain within the trimmed mean's threshold, or a backdoor targeting only rare inputs, is caught by neither defense layer. An active area of adversarial ML research, not a hypothetical edge case.

2. **Sybil attacks** — an adversary controlling many client identities can exceed $\beta$ at will. The trimmed mean guarantee holds only under $f/n < \beta$.

3. **Type 2 attribution** — trimming operates per weight-coordinate, not per client; there is no step in the algorithm that identifies which client is responsible for a trimmed value. Distinguishing legitimate unusual data from deliberate poisoning is not possible from this mechanism alone.

4. **Watcher incentive and data availability** — verification is trustless: a challenger's recomputed root is checked independently on-chain. Data availability is not yet trustless: the true commitment set a challenger needs largely flows through the aggregator itself. Who watches, and how they obtain independent access to the data needed to watch, remain open problems.

5. **Simulated commit phases** — commit and reveal occur within a single round rather than two separate network round-trips. A production deployment would require genuine phase separation.

6. **zk-proof of data integrity (future work)** — a zero-knowledge proof of data provenance between collection and training would close the Type 2 attribution gap. Not implemented in this project — identified as the highest-value direction for future extension.

7. **Manual on-chain pipeline integration** — contract deployment, root posting, and dispute triggers on Vana Moksha testnet are currently invoked via standalone demonstration scripts (`post-checkpoint.ts`, `challenge-checkpoint.ts`) following round completion, rather than being directly wired into the Python Flower ServerApp execution loop.

