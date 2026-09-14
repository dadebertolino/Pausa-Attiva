#!/usr/bin/env bash
# Claim vietati (spec §1): nessun riferimento clinico o promessa di effetto
# nei testi dell'app. Controlla il codice e i testi visibili all'utente.
set -euo pipefail

INCLUDES=(--include='*.dart' --include='*.json' --include='*.arb')

# Radici italiane: basta la sottostringa (iperattivo, iperattività...).
STEMS='adhd|iperattiv|deficit di attenzione|disturbo dell.attenzione|concentrazion|allena l.attenzione|migliora l.attenzione'

# Parole inglesi: solo a parola intera, altrimenti "autofocus" è un falso positivo.
WORDS='attention|focus'

fail=0
if grep -rniE "$STEMS" lib assets "${INCLUDES[@]}"; then fail=1; fi
if grep -rniwE "$WORDS" lib assets "${INCLUDES[@]}"; then fail=1; fi

if [ "$fail" -eq 1 ]; then
  echo "VIETATO: claim non ammessi trovati nei testi dell'app (spec §1)"
  exit 1
fi
echo "OK: nessun claim vietato nei testi dell'app"
