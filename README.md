# ABRAGEN_API

Integrační vrstva (konektor) mezi **ABRA Gen** (REST API) a **B2B portálem** klienta.

Cílem je zpřístupnit data z ABRA Gen pro B2B web ve třech postupných fázích:

1. **Registrace a napojení na adresář** – vyhledání stávajícího zákazníka podle IČO/e-mailu, schvalovací workflow pro nového zákazníka a založení firmy v adresáři ABRA.
2. **Produkty ze skladových karet** – katalog z karet, stav skladu, logika „Na cestě“ (OV + ETA), ceny dle ceníku zákazníka.
3. **Faktury, objednávky a historie nákupů** – seznam dokladů dle IČO, stažení PDF, odvození často nakupovaného zboží.

Do budoucna i **zápis objednávek (OP) z B2B do ABRA** – v návrhu API už s tím počítáme.

## Dokumentace

- [`docs/analyza-napojeni-abra-b2b.md`](docs/analyza-napojeni-abra-b2b.md) – technická analýza: mapování požadavků na objekty ABRA Gen REST API, příklady dotazů, otevřené otázky a checklist.
- [`examples/`](examples/) – spustitelné ukázky (health-check) pro otestování spojení proti reálné instanci ABRA. Spouštět ze stroje na VPN, ne z cloud sandboxu.

## Stav

🚧 Fáze analýzy a návrhu. Implementace konektoru zatím nezapočala – čeká se na volbu technologie a na přístupové údaje k instanci ABRA Gen.
