#!/usr/bin/env bash
# tl-policy.sh — the status→action transition table (§3.6). ONE function maps a normalized state
# verb to exactly one supervision action; every consumer sources this and reads it. Adding a verb
# is a one-line edit that changes all consumers at once.
#
# Principle: absorb only with positive evidence of working. Ambiguity fails closed to polling
# (fallback) — silence never earns the benefit of the doubt.

tl_action() { # verb -> absorb | absorb-slow | actionable | defer | fallback
  case "$1" in
    working)          echo absorb ;;       # not a wake; clears the escalation dedupe marker
    paused|paused:*)  echo absorb-slow ;;   # declared external wait; re-surface on a long cadence
    blocked)          echo actionable ;;    # wedged prompt / permission dialog — the case that writes no status
    needs-decision)   echo actionable ;;    # owner input required -> escalation path (§2.3)
    failed)           echo actionable ;;    # terminal, needs triage
    done)             echo defer ;;         # blips transiently; fast-pathing = false-positive firehose
    *)                echo fallback ;;       # unknown -> poll. Never take fast action from an ambiguous read
  esac
}
