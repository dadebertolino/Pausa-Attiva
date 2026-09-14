#!/usr/bin/env bash
# Vincolo di progetto verificabile: ZERO tracker, analytics, ads, crash reporting.
# Controlla pubspec.yaml E pubspec.lock: un pacchetto vietato può arrivare
# anche come dipendenza indiretta.
set -euo pipefail

DENY=(firebase google_mobile_ads sentry mixpanel amplitude facebook appsflyer
      adjust_sdk onesignal crashlytics posthog segment_analytics datadog
      branch_sdk flutter_branch_sdk bugsnag instabug newrelic smartlook
      unity_ads applovin admob)

fail=0
for file in pubspec.yaml pubspec.lock; do
  [ -f "$file" ] || continue
  for pkg in "${DENY[@]}"; do
    # Match sul nome di pacchetto: inizio riga (con indentazione) + nome + ':'
    if grep -qiE "^\s*[a-z0-9_]*${pkg}[a-z0-9_]*:" "$file"; then
      echo "VIETATO: '$pkg' trovato in $file (policy zero-tracker)"
      fail=1
    fi
  done
done

if [ "$fail" -eq 1 ]; then exit 1; fi
echo "OK: nessun pacchetto tracker/analytics/ads in pubspec.yaml e pubspec.lock"
