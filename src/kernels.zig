//! Formally-gated quant kernels.
//!
//! Each function takes a comptime Gate token as its first argument.
//! The gate IS the type signature — you cannot call computeES without
//! passing a Gate(.es_is_coherent){}, which only compiles if es_is_coherent
//! is in the proof manifest. The proof becomes part of the ABI.

const std = @import("std");
const root = @import("root.zig");

/// Expected Shortfall (Rockafellar-Uryasev).
/// Gate: es_is_coherent — Artzner axioms proved by Lean 4.
/// Gate: var_fails_subadditivity — confirms we are NOT using VaR here.
pub fn computeES(
    comptime _es: root.Gate(.es_is_coherent),
    comptime _var: root.Gate(.var_fails_subadditivity),
    sorted_losses: []const f64,
    alpha: f64,
) f64 {
    _ = _es;
    _ = _var;
    std.debug.assert(alpha > 0.0 and alpha < 1.0);
    std.debug.assert(sorted_losses.len > 0);
    const n = sorted_losses.len;
    const cutoff: usize = @intFromFloat(@ceil((1.0 - alpha) * @as(f64, @floatFromInt(n))));
    const tail_start = n - @min(cutoff, n);
    var sum: f64 = 0.0;
    for (sorted_losses[tail_start..]) |x| sum += x;
    return sum / @as(f64, @floatFromInt(n - tail_start));
}

/// Kelly fraction for a binary bet.
/// Gate: kelly_log_growth — Kelly maximizes log-growth (NOT expected wealth).
/// The type signature makes the log-growth semantics explicit.
pub fn kellyFraction(
    comptime _: root.Gate(.kelly_log_growth),
    win_prob: f64,
    win_payout: f64,
) f64 {
    std.debug.assert(win_prob > 0.0 and win_prob < 1.0);
    std.debug.assert(win_payout > 0.0);
    return (win_prob * (win_payout + 1.0) - 1.0) / win_payout;
}

/// Sharpe ratio.
/// Gate: sharpe_ratio — formula confirmed (mean/std of excess returns).
pub fn sharpeRatio(
    comptime _: root.Gate(.sharpe_ratio),
    returns: []const f64,
    risk_free: f64,
) f64 {
    std.debug.assert(returns.len > 1);
    var mean: f64 = 0.0;
    for (returns) |r| mean += r;
    mean = mean / @as(f64, @floatFromInt(returns.len)) - risk_free;
    var variance: f64 = 0.0;
    for (returns) |r| {
        const d = r - risk_free - mean;
        variance += d * d;
    }
    variance /= @as(f64, @floatFromInt(returns.len - 1));
    return mean / @sqrt(variance);
}

/// CFR epsilon bound: ε ≤ 2U / sqrt(T).
/// Gate: cfr_convergence_rate — convergence proved in QuantLib/Poker/GameTheory_CFR.lean.
/// The bound is a comptime constant derived from the proof — not a runtime parameter.
pub fn cfrEpsilonBound(
    comptime _: root.Gate(.cfr_convergence_rate),
    utility_bound: f64,
    iterations: usize,
) f64 {
    std.debug.assert(utility_bound > 0.0);
    std.debug.assert(iterations > 0);
    return 2.0 * utility_bound / @sqrt(@as(f64, @floatFromInt(iterations)));
}

test "ES with gate compiles and runs" {
    const losses = [_]f64{ -3.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 8.0, 10.0 };
    var sorted = losses;
    std.mem.sort(f64, &sorted, {}, std.sort.asc(f64));
    const es = computeES(.{}, .{}, &sorted, 0.90);
    try std.testing.expect(es > 0.0);
}

test "Kelly fraction for 60/40 coin flip" {
    const f = kellyFraction(.{}, 0.6, 1.0);
    try std.testing.expectApproxEqAbs(0.2, f, 1e-10);
}

test "Sharpe ratio positive for uptrend" {
    const returns = [_]f64{ 0.01, 0.02, 0.015, 0.03, 0.025, 0.02 };
    const sr = sharpeRatio(.{}, &returns, 0.0);
    try std.testing.expect(sr > 0.0);
}

test "CFR epsilon bound decreases with iterations" {
    const eps_100 = cfrEpsilonBound(.{}, 1.0, 100);
    const eps_10000 = cfrEpsilonBound(.{}, 1.0, 10000);
    try std.testing.expect(eps_10000 < eps_100);
}
