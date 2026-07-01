# proof-gate-zig

Zig 0.16 library that enforces formally verified mathematical claims at compile time.

Every function tagged with a `Gate(claim)` type will fail to compile if that claim has been formally refuted — or has never been proven — by a Lean 4 proof assistant.

## The core idea

```zig
const root = @import("proof_gate");

// This compiles: es_is_coherent is formally proven in Lean 4
pub fn computeES(
    comptime _: root.Gate(.es_is_coherent),
    sorted_losses: []const f64,
    alpha: f64,
) f64 { ... }

// This does NOT compile:
// @compileError: "cvar_is_coherent has been FORMALLY REFUTED by Lean 4 counterexample"
pub fn computeCVaR(
    comptime _: root.Gate(.cvar_is_coherent),  // ← compile error here
    ...
) f64 { ... }
```

The gate is zero-cost at runtime — `Gate(claim)` returns a zero-size struct when the claim is proven, or `@compileError` when it is refuted or unproven.

## What "formally refuted" means

The `proof_manifest.json` file encodes the output of a Lean 4 formal verification pipeline (1,400+ theorems across quantitative finance, game theory, signals theory, and mechanism design). Seven claims that appear in financial engineering textbooks were submitted to formal proof and found to be **false**:

| Claim | Status | Why it's wrong |
|---|---|---|
| `cvar_is_coherent` | **REFUTED** | Naive tail-integral CVaR fails translation invariance, monotonicity, and subadditivity simultaneously |
| `kelly_maximizes_expected_wealth` | **REFUTED** | Kelly maximizes log-wealth (E[log W]), not E[W] — these diverge for non-trivial payoffs |
| `sharpe_scale_invariant_all_c` | **REFUTED** | False for c < 0: sign flip makes Sharpe anti-monotone |
| `diversification_always_reduces_variance` | **REFUTED** | Positively correlated assets are a direct counterexample |
| `max_sharpe_always_equal_weights` | **REFUTED** | Optimal weights depend on the full covariance matrix and mean vector |
| `all_martingales_bounded` | **REFUTED** | Simple random walk is an unbounded martingale |
| `es_symmetric_in_alpha` | **REFUTED** | ES(α) ≠ ES(1-α) in general |

Attempting to use any of these claims as a `Gate(...)` type produces a compile error with the refutation reason embedded in the error message.

## Confirmed claims (sample)

110 claims are confirmed. A few:

```zig
Gate(.es_is_coherent)           // ES is coherent: translation, monotone, subadditive, positive-homogeneous
Gate(.kelly_log_growth)         // Kelly criterion maximizes E[log W]
Gate(.var_fails_subadditivity)  // VaR is not subadditive (formal counterexample)
Gate(.cfr_convergence_rate)     // CFR exploitability ≤ 2U/√T
Gate(.gale_shapley_stable)      // Gale-Shapley produces a stable matching
Gate(.minimax_theorem)          // von Neumann minimax (finite matrix games)
Gate(.nash_exists_zerosum)      // Nash equilibrium exists in zero-sum games
Gate(.vcg_strategyproof)        // VCG mechanism is dominant-strategy truthful
Gate(.revenue_equivalence)      // Revenue equivalence theorem
Gate(.no_arbitrage)             // No-arbitrage condition (FTAP)
```

## Usage

```zig
// build.zig.zon
.dependencies = .{
    .proof_gate_zig = .{
        .url = "https://github.com/SMC17/proof-gate-zig/archive/refs/tags/v0.1.0.tar.gz",
    },
},
```

```zig
// src/risk.zig
const gate = @import("proof_gate_zig");

pub fn expectedShortfall(
    comptime _es: gate.Gate(.es_is_coherent),
    comptime _var: gate.Gate(.var_fails_subadditivity),
    sorted_losses: []const f64,
    alpha: f64,
) f64 {
    const cutoff: usize = @intFromFloat(@as(f64, @floatFromInt(sorted_losses.len)) * (1.0 - alpha));
    var sum: f64 = 0;
    for (sorted_losses[cutoff..]) |l| sum += l;
    return sum / @as(f64, @floatFromInt(sorted_losses.len - cutoff));
}
```

## The proof pipeline

```
Lean 4 (Aristotle) → proof_manifest.json → Gate(claim) type → @compileError or zero-size struct
```

The manifest is a flat JSON file mapping claim names to `true` (confirmed), `false` (pending), or entries in `_refuted` (formally disproved with reason). The manifest ships with this package and is updated as new proofs complete.

## Related packages

- `cfr-solver-zig` — CFR solver with ε ≤ 2U/√T exploitability bound enforced as a type invariant
- `formal-counterex-zig` — CLI that prints the formal Lean 4 counterexamples for all 7 refuted claims

## License

MIT
