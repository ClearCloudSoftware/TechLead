#!/usr/bin/env bash
# demo-grill-hits.sh — deterministic grill driver that emits the optional 5th field (bank#) so the
# hits: auto-bump can be tested without a model. Two answers drawn from bank questions 1 and 2, plus
# one owner delta with no bank ref (must not bump anything).
set -eu
printf 'q1\tdecided\tinferred\tYes, create greet.sh.\t1\n'
printf 'q2\tdecided\tinferred\tLiteral hi, no argument.\t2\n'
printf 'q3\topen\towner\tA delta not present in the bank.\n'
