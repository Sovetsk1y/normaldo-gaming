# ─────────────────────────────────────────────────────────────────────────────
# Master switch for EVERY in-game developer affordance:
#   • main-menu reset chips (СБРОС СКИНОВ / КНИГИ / БЕСК.)
#   • in-run dev toggles (immortal, collision shapes, boss spawn, phase jump)
#   • leaderboard "DEV: ТЕСТ ПРИЗА" button
#   • notifications modal dev rows (simulate tap / local 8s / remote test)
#
# Set to `false` for public / open-test / release builds to hide them all.
# Flip back to `true` to restore every dev button at once — that's the only
# change needed to get the full toolset back during development.
#
# (A plain const, not OS.is_debug_build(), so an open-test build that happens to
# be debug-signed still ships clean, and the toggle is explicit + greppable.)
# ─────────────────────────────────────────────────────────────────────────────
const ENABLED := false
