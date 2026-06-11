#!/usr/bin/env bash
# Health-check konektoru ABRA Gen Web API.
#
# Spouštět ze stroje, který na ABRA SÍŤOVĚ vidí (B2B server na Hetzneru přes VPN,
# nebo notebook na VPN). Z cloud sandboxu to NEpůjde – odchozí provoz je blokovaný.
#
# Použití:
#   ABRA_HOST=abra.firma.cz ABRA_PORT=443 ABRA_CONN=firemnidata \
#   ABRA_USER=apiuser ABRA_PASS=tajneheslo ./examples/health-check.sh
#
# ABRA_USER/ABRA_PASS jsou volitelné – bez nich proběhne jen liveness (root).
# Heslo NEdávat do gitu – předávat přes env proměnné.

set -uo pipefail

HOST="${ABRA_HOST:?Nastav ABRA_HOST (např. abra.firma.cz)}"
PORT="${ABRA_PORT:-443}"
CONN="${ABRA_CONN:?Nastav ABRA_CONN (název spojení, např. firemnidata)}"
USER="${ABRA_USER:-}"
PASS="${ABRA_PASS:-}"
BASE="https://${HOST}:${PORT}"

echo "== 1) LIVENESS: root endpoint (bez autentizace) =="
root="$(curl -sS -m 10 -w $'\n%{http_code}' "${BASE}/" 2>&1)"
code="${root##*$'\n'}"; body="${root%$'\n'*}"
echo "HTTP ${code}"
if [ "$code" = "200" ]; then
  if command -v jq >/dev/null 2>&1; then
    echo "$body" | jq --arg c "$CONN" \
      '{product, version, moje_spojeni: (.connections[]? | select(.name==$c))}' \
      || echo "$body"
  else
    echo "$body"
  fi
else
  echo "$body"
  echo ">> Root nevrátil 200 (code=${code}). Síť/VPN, špatný host/port, nebo Web API neběží."
  exit 1
fi

if [ -n "$USER" ]; then
  echo; echo "== 2) READINESS: autentizovaný dotaz (divisions) =="
  rd="$(curl -sS -m 10 -u "${USER}:${PASS}" -w $'\n%{http_code}' \
        "${BASE}/${CONN}/divisions?select=ID&take=1" 2>&1)"
  rcode="${rd##*$'\n'}"; rbody="${rd%$'\n'*}"
  echo "HTTP ${rcode}"; echo "$rbody"
  case "$rcode" in
    200) echo ">> OK: přihlášení i čtení dat funguje." ;;
    401) echo ">> 401: špatné přihlášení nebo chybí flag 'Nevizuální přihlášení (API)'." ;;
    403) echo ">> 403: uživatel nemá právo na daný objekt." ;;
    404) echo ">> 404: zkontroluj název spojení '${CONN}'." ;;
    000) echo ">> Nedostupné (000): síť/VPN/TLS." ;;
    *)   echo ">> Neočekávaný stav ${rcode}." ;;
  esac
else
  echo; echo "(readiness přeskočen – pro test přihlášení nastav ABRA_USER a ABRA_PASS)"
fi
