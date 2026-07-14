// Negative CI probe. This file is INTENTIONALLY expected to fail compilation:
// cvar_is_coherent is FORMALLY REFUTED in proof_manifest.json, so Gate() must
// reject it. The CI workflow runs `zig build gate-refuted` and treats the
// build failure as the PASS signal — proving the compiler enforces the
// refutation policy. If this ever compiles, the gate is broken.
const proof = @import("proof-gate-zig");

pub fn main() void {
    const _g = proof.Gate(.cvar_is_coherent){};
    _ = _g;
}
