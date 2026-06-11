# Technická analýza napojení ABRA Gen ↔ B2B

Mapování klientových požadavků na konkrétní objekty a volání **REST API ABRA Gen**.
Dokument je živý – po pátečním ladění a po získání přístupu k instanci ho doplníme o ověřené názvy polí a ID reportů.

**Legenda:**
- ✅ ověřeno v oficiální dokumentaci ABRA Gen
- ⚠️ nutno potvrdit na konkrétní instanci klienta (verze, číselné řady, konfigurace ceníků/reportů)
- 💡 návrh / doporučení k diskusi

---

## 0. Společný technický základ

### 0.1 REST API ABRA Gen

- ✅ API je postaveno nad standardem **OpenAPI 3.0**, vrací **JSON**, architektura REST. Na instanci je k dispozici **Swagger** a model objektů.
- ✅ Základní tvar URL: `https://<host>:<port>/<spojeni>/<businessObjekt>`
  např. `https://abra.firma.cz:699/firemnidata/issuedinvoices`
- ✅ Introspekce modelu konkrétního objektu (skvělé pro ověření názvů polí):
  `GET /<spojeni>/api-docs/model/<nazev_v_jednotnem_cisle>` – např. `.../api-docs/model/firm`

### 0.2 Autentizace ✅

Dvě varianty (záleží na verzi a konfiguraci instance):
- **HTTP Basic Auth** – `login:heslo` v Base64 v hlavičce `Authorization`. Lze přidat `;lock_connection` pro držení spojení.
- **OAuth 2.0 / JWT** – novější verze ABRA Gen; přihlášení přes access/refresh token (nutné zapnout v agendě *Definice JWT* a u uživatele povolit *JWT přihlášení*).

> ⚠️ **Důležité:** API uživatel musí mít v ABRA zaškrtnuto **„Nevizuální přihlášení (API)“**, jinak ho API nepustí dál. To je potřeba založit/ověřit na straně klienta.

💡 Konektor bude přihlašovací údaje držet u sebe (B2B je nikdy nevidí) a spojení/token recyklovat – každé volání ABRA jinak prochází autentizací.

### 0.3 Dotazovací jazyk (AbraQL) ✅

Klauzule se předávají jako URL parametry; mezery se kódují jako `+`, pole oddělená čárkou:

| Klauzule | Význam | Příklad |
|----------|--------|---------|
| `select` | výběr polí | `select=ID,Code,Name` |
| `where`  | filtr (`eq`, `like`, `and`, `or`, `ge`, `le`, …) | `where=OrgIdentNumber+eq+'12345678'` |
| `orderby`| řazení | `orderby=DocDate+desc` |
| `take` / `skip` | stránkování | `skip=0&take=50` |
| `expand` | natažení vazby | `expand=Firm_ID(ID,Code,Name)` |

Pro složitější dotazy lze použít i **POST** s JSON tělem (rozšířené dotazování).

### 0.4 Prerekvizity (technický checklist k zahájení)

- [ ] Zapnuté REST API na ABRA Gen + **adresa, port, název spojení**.
- [ ] API uživatel s právem **„Nevizuální přihlášení (API)“** + heslo/token.
- [ ] Verze ABRA Gen (kvůli dostupnosti objektů/polí a OAuth2).
- [ ] Síťová dostupnost: B2B server (Hetzner) → ABRA. ⚠️ **VPN / povolení IP / reverzní proxy** – řešit s IT klienta. Doporučení: nevystavovat ABRA API přímo do internetu.
- [ ] Rozsah práv: fáze 1–2 **čtení**, zakládání firem (a později OP) **zápis**.

---

## Fáze 1 — Registrace a napojení na adresář

### 1A) Stávající zákazník – vyhledání v adresáři

Uživatel na webu zadá **IČO nebo e-mail**. Konektor prohledá adresář firem ABRA.

- ✅ IČO je v objektu **Firm** v poli **`OrgIdentNumber`**.
- ⚠️ E-mail bývá na adrese firmy (`ResidenceAddress_ID.Email`) – přesnou cestu potvrdit na instanci (může být i na provozovně / komunikaci).

**Vyhledání podle IČO:**
```
GET /<spojeni>/firms
    ?select=ID,Code,Name,OrgIdentNumber
    &expand=ResidenceAddress_ID(Email)
    &where=OrgIdentNumber+eq+'12345678'
```

**Vyhledání podle e-mailu:**
```
GET /<spojeni>/firms
    ?select=ID,Code,Name,OrgIdentNumber
    &expand=ResidenceAddress_ID(Email)
    &where=ResidenceAddress_ID.Email+eq+'zakaznik@firma.cz'
```

**Tok:** ABRA jen **potvrdí existenci** a vrátí `ID` firmy + e-mail. Heslo generuje B2B, rozesílá se přes SMTP (mimo ABRA).

💡 **Párovací klíč.** Souhlasím s IČO jako primárním klíčem, ale není stoprocentní:
- Zákazník bez IČA (drobní, nepodnikatelé, zahraniční) – IČO chybí nebo není unikátní.
- 💡 **Doporučení:** primární klíč = `OrgIdentNumber` (když existuje); po prvním spárování si **B2B uloží `Firm_ID` z ABRA** a dál páruje přes něj (stabilní, jednoznačné). E-mail brát jen jako kontaktní údaj, ne jako klíč (nemusí být unikátní).
- ⚠️ Otázka na klienta: jak řešit zákazníky bez IČA – povolit ruční spárování obchoďákem?

### 1B) Nový zákazník – schválení + založení firmy v ABRA

1. Web zobrazí výzvu kontaktovat obchodního zástupce (okno dle přílohy).
2. V **B2B** vznikne **žádost o schválení** (schvaluje ADMIN / zaměstnanec s právem) – tato část je **logika B2B, ne ABRA**.
3. Obchoďák domluví ceník a podmínky → přiřadí ceník v B2B (nebo přes asistentku).
4. Po schválení se **zapíše firma do adresáře ABRA** i s vazbou na ceník.

**Založení firmy (zápis do ABRA):**
```
POST /<spojeni>/firms
Content-Type: application/json

{
  "Name": "Nová firma s.r.o.",
  "OrgIdentNumber": "12345678",
  "VATIdentNumber": "CZ12345678",
  "ResidenceAddress": { "Street": "...", "City": "...", "PostCode": "..." }
  // ⚠️ vazba na ceník – pole nutno potvrdit (viz níže)
}
```

⚠️ **Co je nutné potvrdit na instanci** (přes `api-docs/model/firm` nebo Swagger):
- **Povinná pole** pro vznik firmy (minimálně `Name`; typicky i číselná řada/kód, struktura adresy jako vnořený objekt).
- **Jak je modelováno přiřazení ceníku k firmě.** V ABRA to bývá buď přímé pole na firmě (např. `PriceList_ID`), nebo přes **kategorii firmy / obchodní podmínky**. Tohle je klíčové pro celou fázi 2 (ceny) → potřebujeme znát přesný mechanismus.
- ⚠️ U POST/PUT může v ABRA **záležet na pořadí polí** v JSON.

---

## Fáze 2 — Produkty ze skladových karet

### 2.1 Katalog z karet ✅

Spojovací klíč B2B ↔ ABRA = **kód karty** (`Code`). Proto je správné, že se kódy sjednocují a stabilizují.

```
GET /<spojeni>/storecards
    ?select=ID,Code,Name,EAN
    &orderby=Code
    &skip=0&take=100
```

### 2.2 Stav skladu ✅ / ⚠️

- ✅ Skladové karty mají hlavní kartu **`StoreCards`** a dílčí (po skladech) **`StoreSubcards`** s polem **`Quantity`** (vč. vazeb `storecard_id`, `store_id`).
- ⚠️ **Fyzický vs. disponibilní stav.** „0 skladem“ – rozhodnout, zda fyzické množství, nebo **disponibilní** (fyzické − rezervace). Pro e-shop je obvykle správně **disponibilní**.
- ⚠️ Přes který sklad/sklady se stav počítá (jen prodejní sklad, nebo součet)?

**Logika zobrazení produktu (návrh):**

| Stav | Zobrazení na webu |
|------|-------------------|
| Disponibilní > 0 | Skladem |
| Disponibilní = 0 **a** existuje otevřená OV s ETA | **„Na cestě“**, termín = **ETA + 14 dní** |
| Disponibilní = 0 **a** žádná OV s ETA | Produkt se skryje |

### 2.3 „Na cestě“ z objednávek vydaných (OV) ⚠️

OV = **objednávka vydaná** (dodavateli). Hledáme **otevřené** OV s danou kartou a vyplněnou ETA.

- ✅ Objekt **`IssuedOrders`** (model `issuedorder`) má pole termínu dodání (v API datové pole typu `deliverydate$date`).
- ⚠️ Potvrdit: zda je ETA na **hlavičce** dokladu, nebo na **řádku** (`IssuedOrderRows` / položce u dané karty) – pro e-shop nás zajímá termín k položce.
- ⚠️ Definici **„otevřená/nevyřízená“** OV (nedodané množství > 0).

```
GET /<spojeni>/issuedorders
    ?select=ID,DocumentNumber,DeliveryDate
    &expand=Rows(StoreCard_ID,Quantity,DeliveryDate)   // ⚠️ názvy řádků potvrdit
    &where=...otevřené + daná karta...
```
→ z výsledku vzít nejbližší ETA a zobrazit `ETA + 14 dní`.

### 2.4 Ceny dle ceníku zákazníka ⚠️

Každý zákazník vidí ceny svého ceníku (navázáno přes firmu – viz 1B).

- ⚠️ Objekty **`PriceLists`** / **`PriceListItems`** (přesné názvy + struktura potvrdit). Cena se hledá podle ceníku + karty:
```
GET /<spojeni>/pricelistitems
    ?select=Price,Currency,ValidFrom,ValidTo
    &where=PriceList_ID+eq+'<idCeniku>'+and+StoreCard_ID+eq+'<idKarty>'
```
- ⚠️ Klíčová otázka (propojuje fázi 1 a 2): **jak z firmy zjistíme její ceník?** (pole na firmě vs. kategorie/obchodní podmínky). Bez toho neumíme „každý vidí svoje ceny“.
- ⚠️ Řešení měny, platnosti (`ValidFrom`/`ValidTo`), slev a DPH.

---

## Fáze 3 — Faktury, objednávky a historie nákupů

Vše párováno přes IČO zákazníka (resp. uložené `Firm_ID`).

### 3.1 Seznam faktur (vydaných) ✅

- ✅ Objekt **`IssuedInvoices`**, vazba na firmu přes **`Firm_ID`**.
- 💡 Omezení na **12 měsíců** = filtr na datum dokladu.

```
GET /<spojeni>/issuedinvoices
    ?select=ID,DocumentNumber,DocDate,DueDate,Amount,RemainingAmount
    &expand=Firm_ID(ID,OrgIdentNumber,Name)
    &where=Firm_ID.OrgIdentNumber+eq+'12345678'+and+DocDate+ge+'2025-06-11'
    &orderby=DocDate+desc
```
> ⚠️ Přesné názvy polí částek/čísla dokladu/data potvrdit (`DocumentNumber` × `DisplayName`, `DocDate`, `Amount`).

### 3.2 Seznam objednávek (přijatých, OP) ✅ / ⚠️

OP = **objednávka přijatá** (od zákazníka). Objekt **`ReceivedOrders`**, opět filtr přes `Firm_ID.OrgIdentNumber`.

```
GET /<spojeni>/receivedorders
    ?select=ID,DocumentNumber,DocDate,Amount
    &where=Firm_ID.OrgIdentNumber+eq+'12345678'+and+DocDate+ge+'2025-06-11'
    &orderby=DocDate+desc
```

### 3.3 Stažení PDF faktury ✅ / ⚠️

- ✅ Tisk/export přes příponu **`.pdf`** na zdroji + parametr **`report`** (lze i `report-name`, `report-lang`). Podporováno **PDF/XLSX/CSV**.
```
GET /<spojeni>/issuedinvoices/<idFaktury>.pdf?report=<idReportu>
```
- ⚠️ **`<idReportu>` je specifické pro instanci** (klient má vlastní/upravené tiskové reporty). Musíme získat ID reportu pro fakturu (a případně pro OP).

### 3.4 „Co zákazník často nakupuje“ 💡

- 💡 Odvodíme agregací **položek** faktur/objednávek (`IssuedInvoiceRows` / `ReceivedOrderRows`) seskupením podle karty (`StoreCard_ID`) za období – TOP N podle množství/četnosti.
- ⚠️ Potvrdit názvy objektů řádků a dostupnost `StoreCard_ID` na řádku.
- 💡 Výpočet provádět v konektoru (ne tlačit logiku do ABRA dotazů).

---

## Budoucí fáze — zápis objednávek (OP) z B2B do ABRA

Teď neřešíme, ale návrh API na to musí být připravený:
- 💡 Zápis přes **`POST /receivedorders`** s hlavičkou + řádky (vazba `Firm_ID`, `StoreCard_ID`, množství, ceník/cena, číselná řada).
- 💡 Konektor proto navrhujeme **obousměrně** (čtení i zápis) s jednotnou autentizací a mapováním identifikátorů, aby pozdější přidání zápisu OP nebylo přestavba.

---

## Architektura konektoru (návrh) 💡

```
   B2B web (Hetzner)  ──HTTPS──►  KONEKTOR (tento repozitář)  ──VPN/REST──►  ABRA Gen API
                                   ├─ drží přihlášení/token k ABRA
                                   ├─ čistá REST rozhraní pro B2B (firms, products, invoices…)
                                   ├─ CACHE katalogu a stavů skladu (periodický sync)
                                   └─ mapování IČO ↔ Firm_ID, agregace historie
```

- 💡 **Cache + periodický sync** katalogu a skladů – nevolat ABRA při každém zobrazení stránky (každé volání prochází autentizací a zatěžuje ERP). Stav skladu např. refresh po pár minutách.
- 💡 Konektor jako jediné místo, kde jsou uložené přístupy do ABRA.

---

## Konsolidovaný seznam otázek na klienta (na pátek)

**Přístup a prostředí**
1. Verze ABRA Gen + adresa, port, název spojení.
2. API uživatel s „Nevizuální přihlášení (API)“ – Basic Auth, nebo OAuth2/JWT?
3. Síť: jak se B2B (Hetzner) dostane k ABRA – VPN / povolení IP / proxy?

**Fáze 1**
4. Jak řešit zákazníky **bez IČA** (ruční spárování?).
5. Kde přesně je na firmě **e-mail** (`ResidenceAddress_ID.Email`?).
6. **Povinná pole** pro založení firmy + struktura adresy.
7. **Jak je k firmě přiřazen ceník** (pole na firmě vs. kategorie/obchodní podmínky)? ← propojuje s fází 2.

**Fáze 2**
8. **Disponibilní vs. fyzický** stav; přes které sklady počítat.
9. ETA na OV – **hlavička vs. řádek**; definice „otevřené“ OV.
10. Objekty/struktura **ceníků** (`PriceLists` / `PriceListItems`).

**Fáze 3**
11. **ID tiskových reportů** pro fakturu (a OP) → PDF.
12. Přesné názvy polí na faktuře/OP (číslo, datum, částka).
13. Potvrdit objekty **řádků** dokladů pro „často nakupuje“.
