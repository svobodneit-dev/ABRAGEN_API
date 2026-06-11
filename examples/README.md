# Ukázkové requesty na ABRA Gen Web API

⚠️ **Kde spouštět:** ze stroje, který na ABRA Gen **síťově vidí** – typicky B2B server
na Hetzneru přes VPN nebo notebook připojený na VPN. **Z cloud sandboxu Claude to
nepůjde** – tamní síťová politika blokuje odchozí provoz (i `example.com` vrací 403).

## Soubory

| Soubor | K čemu |
|--------|--------|
| `health-check.http` | Liveness (root) + readiness (divisions) pro VS Code *REST Client* / IntelliJ HTTP Client. Nahoře vyplň `@host`, `@port`, `@conn`, `@user`, `@pass`. |
| `health-check.sh` | Totéž přes `curl`. Parametry přes env proměnné. |

## Spuštění skriptu

```bash
ABRA_HOST=abra.firma.cz ABRA_PORT=443 ABRA_CONN=firemnidata \
ABRA_USER=apiuser ABRA_PASS=tajneheslo \
./examples/health-check.sh
```

Bez `ABRA_USER`/`ABRA_PASS` proběhne jen liveness (root endpoint, bez autentizace).

## Bezpečnost

- Heslo/token **nedávat do gitu** – předávat přes env proměnné (nebo `.env` mimo verzování).
- ABRA Web API **nevystavovat přímo do internetu** – přístup řešit přes VPN / allowlist.
