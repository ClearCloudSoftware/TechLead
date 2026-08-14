#!/usr/bin/env bash
# demo-standards-hits.sh — deterministic Standards judge that emits the optional 4th field (the cited
# review-rubric rule number) so the review-side hits: bump can be tested without a model. Two findings
# citing rubric rules 1 and 2, plus a baseline smell with no rubric ref (must bump nothing).
set -eu
printf 'standards-violation\tf.txt: broke rubric rule 1\tf.txt\t1\n'
printf 'standards-violation\tf.txt: broke rubric rule 2\tf.txt\t2\n'
printf 'standards-smell\tf.txt: a baseline smell, no rubric rule\tf.txt\n'
