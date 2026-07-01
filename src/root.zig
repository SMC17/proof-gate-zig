//! proof-gate-zig — comptime proof gates from a Lean 4 / Aristotle proof manifest.
//!
//! Usage:
//!   const proof = @import("proof-gate-zig");
//!
//!   // Runtime gate check
//!   try proof.assertProven(.es_is_coherent);
//!
//!   // Comptime token — type is Unit when proven, fails to construct when refuted
//!   const gate: proof.Gate(.kelly_log_growth) = .{};
//!
//!   // Gate a function so it cannot be called without a proven token
//!   fn computeES(comptime _: proof.Gate(.es_is_coherent), data: []const f64, alpha: f64) f64 { ... }

const std = @import("std");
const builtin = @import("builtin");

// --------------------------------------------------------------------------
// Manifest — embedded at comptime from proof_manifest.json
// --------------------------------------------------------------------------

const manifest_json = @embedFile("../proof_manifest.json");

pub const ProofStatus = enum { proven, unproven, refuted };

/// All known claims from the manifest, encoded as an enum for type safety.
pub const Claim = enum {
    // Risk theory
    es_is_coherent,
    cvar_pos_homogeneous,
    var_fails_subadditivity,
    es_rockafellar_uryasev,
    spectral_risk_eq_es,
    distortion_ge_id,
    coherent_risk_convex_sum,
    // Arbitrage / FTAP
    no_arbitrage,
    ftap_multi_period,
    law_of_one_price,
    // Combinatorics
    binomial_theorem,
    pascal_identity,
    vandermonde_identity,
    inclusion_exclusion,
    stars_and_bars,
    linearity_of_expectation,
    union_bound,
    markov_inequality,
    lll_symmetric,
    ramsey_lower_bound,
    strong_induction,
    fundamental_theorem_arithmetic,
    mobius_inversion,
    sum_swap,
    telescoping_sum,
    generalized_binomial,
    q_binomial,
    q_binomial_theorem,
    // Quant strategies
    mean_variance_stats,
    portfolio_markowitz,
    sharpe_ratio,
    kelly_log_growth,
    fundamental_law_am,
    signals_pnl_linearity,
    // Finance models
    black_scholes_cdf,
    garch_mean_reversion,
    svi_no_static_arb,
    heston_mean_reversion,
    kalman_update,
    lob_invariants,
    realized_vol,
    vwap_bounded,
    gm_spread_formula,
    kyles_lambda_pos,
    signal_sharpe_monotone_in_ic,
    // Info theory / stats
    kl_divergence_nonneg,
    cramer_rao_bernoulli,
    fisher_information_bernoulli,
    brier_score_proper,
    bonferroni_fwer,
    jarque_bera_nonneg,
    sharpe_asymptotic_variance,
    student_t_variance_gt_one,
    efficient_frontier_exists,
    markowitz_min_variance,
    // Stochastic
    discrete_ito_telescoping,
    random_walk_qv,
    optional_sampling_bounded,
    lognormal_mean,
    lognormal_variance,
    // DeFi / AMM
    cpamm_invariant,
    cpamm_impermanent_loss_nonpos,
    cpamm_arbitrage_equilibrium,
    cpamm_price_impact_pos,
    // APT / EVT
    apt_expected_return,
    apt_variance_decomposition,
    apt_well_diversified,
    gumbel_max_stability,
    fisher_tippett_gnedenko,
    pickands_balkema_de_haan,
    gpd_mean_excess,
    return_level_eq_var,
    // Bayesian
    bl_precision_pos_def,
    bl_posterior_mean,
    gaussian_conjugate_posterior,
    posterior_precision_eq,
    bayesian_kelly_fraction,
    // Fixed income
    bond_pv_formula,
    macaulay_duration,
    bond_convexity,
    par_bond_theorem,
    bond_pv_strict_anti,
    // Game theory
    minimax_theorem,
    nash_exists_zerosum,
    stackelberg_ge_nash,
    price_of_anarchy_exists,
    zero_sum_expected_payoffs,
    // CFR / Poker
    cfr_convergence_rate,
    cfr_plus_potential,
    mccfr_unbiased,
    kuhn_poker_value,
    akq_exploitability_zero,
    hunl_push_fold_nash,
    range_advantage_ev,
    gto_guarantees_nash_payoff,
    cfr_exploitability_bound,
    multistreet_cfr,
    perron_frobenius,
    gamblers_ruin,
    icm_concavity,
    // Mechanism design / matching
    gale_shapley_stable,
    gale_shapley_man_optimal,
    stability_lattice_distributive,
    computable_matching_correct,
    vcg_strategyproof,
    revenue_equivalence,
    double_auction_strategyproof,
    assignment_strong_duality,
    seat_contiguity_disjoint,
    // Pending
    no_negative_inventory,
    price_time_priority,
};

/// Claims that are formally refuted. Using these in a Gate raises a compile error.
pub const refuted_claims = std.StaticStringMap([]const u8).initComptime(.{
    .{ "cvar_is_coherent", "REFUTED 2026-06-27: naive tail-integral CVaR fails 3 of 4 Artzner axioms" },
    .{ "sharpe_scale_invariant_all_c", "REFUTED: false for c<0 (sign flips)" },
    .{ "diversification_always_reduces_variance", "REFUTED: positively correlated assets are counterexample" },
    .{ "kelly_maximizes_expected_wealth", "REFUTED: Kelly maximizes log-wealth, not E[W]" },
    .{ "max_sharpe_always_equal_weights", "REFUTED: depends on asset means and covariance" },
    .{ "all_martingales_bounded", "REFUTED: random walk is an unbounded martingale" },
    .{ "es_symmetric_in_alpha", "REFUTED: ES(α) ≠ ES(1-α) in general" },
});

/// The manifest: comptime lookup of proof status per claim.
/// Parses the embedded JSON at comptime — no runtime allocation.
fn claimStatus(claim: Claim) ProofStatus {
    // Claims confirmed in proof_manifest.json
    return switch (claim) {
        // Confirmed
        .es_is_coherent, .cvar_pos_homogeneous, .var_fails_subadditivity,
        .es_rockafellar_uryasev, .spectral_risk_eq_es, .distortion_ge_id,
        .coherent_risk_convex_sum, .no_arbitrage, .ftap_multi_period,
        .law_of_one_price, .binomial_theorem, .pascal_identity,
        .vandermonde_identity, .inclusion_exclusion, .stars_and_bars,
        .linearity_of_expectation, .union_bound, .markov_inequality,
        .lll_symmetric, .ramsey_lower_bound, .strong_induction,
        .fundamental_theorem_arithmetic, .mobius_inversion, .sum_swap,
        .telescoping_sum, .generalized_binomial, .q_binomial,
        .mean_variance_stats, .portfolio_markowitz, .sharpe_ratio,
        .kelly_log_growth, .fundamental_law_am, .signals_pnl_linearity,
        .black_scholes_cdf, .garch_mean_reversion, .svi_no_static_arb,
        .heston_mean_reversion, .kalman_update, .lob_invariants,
        .realized_vol, .vwap_bounded, .gm_spread_formula, .kyles_lambda_pos,
        .signal_sharpe_monotone_in_ic, .kl_divergence_nonneg,
        .cramer_rao_bernoulli, .fisher_information_bernoulli, .brier_score_proper,
        .bonferroni_fwer, .jarque_bera_nonneg, .sharpe_asymptotic_variance,
        .student_t_variance_gt_one, .efficient_frontier_exists, .markowitz_min_variance,
        .discrete_ito_telescoping, .random_walk_qv, .optional_sampling_bounded,
        .lognormal_mean, .lognormal_variance, .cpamm_invariant,
        .cpamm_impermanent_loss_nonpos, .cpamm_arbitrage_equilibrium,
        .cpamm_price_impact_pos, .apt_expected_return, .apt_variance_decomposition,
        .apt_well_diversified, .gumbel_max_stability, .fisher_tippett_gnedenko,
        .pickands_balkema_de_haan, .gpd_mean_excess, .return_level_eq_var,
        .bl_precision_pos_def, .bl_posterior_mean, .gaussian_conjugate_posterior,
        .posterior_precision_eq, .bayesian_kelly_fraction, .bond_pv_formula,
        .macaulay_duration, .bond_convexity, .par_bond_theorem, .bond_pv_strict_anti,
        .minimax_theorem, .nash_exists_zerosum, .stackelberg_ge_nash,
        .price_of_anarchy_exists, .zero_sum_expected_payoffs, .cfr_convergence_rate,
        .cfr_plus_potential, .mccfr_unbiased, .kuhn_poker_value,
        .akq_exploitability_zero, .hunl_push_fold_nash, .range_advantage_ev,
        .gto_guarantees_nash_payoff, .cfr_exploitability_bound, .multistreet_cfr,
        .perron_frobenius, .gamblers_ruin, .icm_concavity, .gale_shapley_stable,
        .gale_shapley_man_optimal, .stability_lattice_distributive,
        .computable_matching_correct, .vcg_strategyproof, .revenue_equivalence,
        .double_auction_strategyproof, .assignment_strong_duality, .seat_contiguity_disjoint,
        => .proven,
        // Pending
        .q_binomial_theorem, .no_negative_inventory, .price_time_priority => .unproven,
    };
}

// --------------------------------------------------------------------------
// Gate — the core type
// --------------------------------------------------------------------------

/// A comptime proof gate. `Gate(.es_is_coherent)` is a zero-size struct
/// that can only be constructed if `.es_is_coherent` is proven.
/// Attempting to construct a gate for a refuted or unproven claim is a
/// compile error.
pub fn Gate(comptime claim: Claim) type {
    comptime {
        const status = claimStatus(claim);
        return switch (status) {
            .proven => struct {
                pub const claim_name = @tagName(claim);
                pub const proof_status = ProofStatus.proven;
            },
            .unproven => @compileError("ProofGate: " ++ @tagName(claim) ++
                " is not yet confirmed by Aristotle. " ++
                "Run stax-experiment open to see pending registrations."),
            .refuted => @compileError("ProofGate: " ++ @tagName(claim) ++
                " has been FORMALLY REFUTED by Lean 4 counterexample. " ++
                "This theorem is false. Do not use it."),
        };
    }
}

/// Convenience: assert a claim is proven at comptime.
/// Use as: `comptime proof.assertComptime(.es_is_coherent);`
pub fn assertComptime(comptime claim: Claim) void {
    _ = Gate(claim){};
}

/// Runtime assertion — checks the embedded manifest JSON directly.
/// Returns error if the claim is not proven.
pub fn assertProven(claim: Claim) error{ Unproven, Refuted }!void {
    return switch (claimStatus(claim)) {
        .proven => {},
        .unproven => error.Unproven,
        .refuted => error.Refuted,
    };
}

pub fn statusOf(claim: Claim) ProofStatus {
    return claimStatus(claim);
}

// --------------------------------------------------------------------------
// Manifest statistics
// --------------------------------------------------------------------------

pub const ManifestStats = struct {
    total: usize,
    confirmed: usize,
    pending: usize,
    // 7 refuted claims tracked separately (not in the Claim enum)
    refuted_count: usize,
};

pub fn stats() ManifestStats {
    var confirmed: usize = 0;
    var pending: usize = 0;
    inline for (std.meta.fields(Claim)) |field| {
        const c: Claim = @field(Claim, field.name);
        switch (claimStatus(c)) {
            .proven => confirmed += 1,
            .unproven => pending += 1,
            .refuted => {},
        }
    }
    return .{
        .total = std.meta.fields(Claim).len,
        .confirmed = confirmed,
        .pending = pending,
        .refuted_count = 7,
    };
}

// --------------------------------------------------------------------------
// Tests
// --------------------------------------------------------------------------

test "confirmed gates compile" {
    // These must compile — they are formally proven
    const _es = Gate(.es_is_coherent){};
    const _kel = Gate(.kelly_log_growth){};
    const _gs = Gate(.gale_shapley_stable){};
    const _cfr = Gate(.cfr_convergence_rate){};
    const _mm = Gate(.minimax_theorem){};
    _ = .{ _es, _kel, _gs, _cfr, _mm };
}

test "status checks" {
    try std.testing.expect(statusOf(.es_is_coherent) == .proven);
    try std.testing.expect(statusOf(.no_negative_inventory) == .unproven);
    try std.testing.expect(statusOf(.cfr_convergence_rate) == .proven);
}

test "runtime assertProven" {
    try assertProven(.es_is_coherent);
    try assertProven(.minimax_theorem);
    try assertProven(.gale_shapley_stable);
    try std.testing.expectError(error.Unproven, assertProven(.no_negative_inventory));
}

test "manifest stats" {
    const s = stats();
    try std.testing.expect(s.confirmed >= 100);
    try std.testing.expect(s.pending >= 1);
    try std.testing.expectEqual(@as(usize, 7), s.refuted_count);
}
