# PNP-ATTACK

> A sovereign-compute adversarial-verification layer: a multi-agent infrastructure that attacks the P vs NP problem space, seals every attempt to a WORM ledger, and stress-tests the P/NP swarm by refuting malformed and unprovable inputs.

## OVERVIEW

`pnp-attack` is a legitimate sovereign-compute **test and adversarial-verification** layer, not a harmful tool. Its job is to exercise the SnapKitty P/NP swarm the hard way: it generates hard SAT instances, runs a DPLL solver, and coordinates multi-agent proof search — then writes an immutable, Merkle-chained audit trail of every attempt. By documenting the known barriers (relativization, natural proofs, algebrization) and refusing to admit spurious "proofs," it strengthens the swarm's verification discipline.

> Ω ← TRUST ∧ CODE

Every attempt is sealed, verifiable, and timestamped. There is no silent pass.

## WHAT IT IS

A Rust coordinator binary plus Fortran and APL partners:

| Component | File | Role |
|-----------|------|------|
| Rust coordinator | `src/coordinator.rs` | `ProofSearchCoordinator`: ATLAS (strategy) → TENSOR (compute) → LEDGE (verify) → AXIOM (seal) |
| Fortran SAT solver | `fortran/sat_solver.f90` | DPLL with unit propagation + pure-literal elimination |
| APL problem generator | `apl/problem_generator.apl` | Random 3-SAT at the phase transition (clauses/vars ≈ 4.267) |
| AXIOM formalization | (see `axiom-proof/src/stdlib/`) | complexity classes, Turing machines, SAT, NP-completeness |

The coordinator explores five strategies — `circuit_lower_bounds`, `diagonalization`, `algebraic_geometry`, `combinatorial`, `randomized_search` — and records each as `Success | Failure | Incomplete | Timeout | Error`.

## ARCHITECTURE / COMPONENTS

```
pnp-attack/
├── Cargo.toml              # [[bin]] pnp-coordinator → src/coordinator.rs
│                          # deps: sha2, serde, serde_json
├── src/
│   └── coordinator.rs      # ProofAttempt, Merkle root, WORM ledger append
├── fortran/
│   └── sat_solver.f90      # DPLL solver, MAX_VARS=10000, MAX_CLAUSES=100000
├── apl/
│   └── problem_generator.apl # GenerateHardSAT, SealToWORM, AnalyzeInstances
├── PVS_NP.md               # Design doc: problem statement, barriers, strategies
└── metadata.json           # Bifrost WORM Chain provenance, Ed25519 plasma_gate
```

**Verification pipeline (per attempt):** `select_strategy` → `execute_search` (calls solver) → `verify_attempt` (LEDGE, well-formedness) → `seal_attempt` (AXIOM: SHA-256 seal + Merkle root + append to `pnp_worm.jsonl`).

**Known barriers documented** (so the swarm does not waste cycles):
- **Relativization** (Baker–Gill–Solovay 1975) — oracles separate P^A=NP^A from P^B≠NP^B.
- **Natural proofs** (Razborov–Rudich 1997) — blocks super-polynomial circuit lower bounds under crypto assumptions.
- **Algebrization** (Aaronson–Wigderson 2009) — extends relativization to algebraic oracles.

## HOW IT FITS THE CONSTELLATION

`pnp-attack` is the *adversary in the loop* for the P/NP swarm (`AGENTS.md` §5). It implements the swarm's adversarial-verification discipline: finding a witness is NP-hard, verifying is P-time, and the repo only admits P-verifiable proofs. By generating hard instances and sealing every failure, it supplies negative evidence and refutes malicious/incorrect inputs the swarm might otherwise accept.

`metadata.json` carries the Bifrost WORM Chain link `Bifrost_WORM_Chain_20260710_01`, AES-256-GCM encryption, and `plasma_gate: Ed25519_Enforced` — every attempt is anchored to the sovereign trust root.

## BUILD / USAGE / INSTALL

```bash
cd pnp-attack
cargo build --release
cargo test
cargo run --release --bin pnp-coordinator     # runs 10 phases, seals to pnp_worm.jsonl

# Fortran SAT solver (standalone)
gfortran -O3 -o sat_solver fortran/sat_solver.f90
./sat_solver
```

The coordinator prints a summary with total attempts, successes, failures, incomplete counts, and the final Merkle root.

## KEY FILES REFERENCE

- `src/coordinator.rs:48` — `select_strategy` maps phase → proof strategy.
- `src/coordinator.rs:60` — `execute_search` (TENSOR) runs the chosen strategy.
- `src/coordinator.rs:153` — `verify_attempt` (LEDGE) well-formedness check.
- `src/coordinator.rs:159` — `seal_attempt` (AXIOM) SHA-256 + Merkle root.
- `src/coordinator.rs:180` — `compute_merkle_root` pairwise SHA-256 reduction.
- `fortran/sat_solver.f90:205` — `dpll` recursive solver with `unit_propagate`/`pure_literal`.
- `apl/problem_generator.apl:5` — `GenerateHardSAT` phase-transition instance generator.

## LICENSE

Sovereign Source License. Maintained by SnapKitty Agent OS (Operator: Ahmad Ali Parr).
