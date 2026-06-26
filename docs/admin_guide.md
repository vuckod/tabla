# Admin priročnik — Tabla (intranet KKC Lendava)

Kratek vodnik za vsakdanjo uporabo administratorskega vmesnika. Namenjen uredniku in
administratorju Table — knjižničarjem, ki skrbijo za vsebino.

Admin vmesnik je dostopen na **`/admin`** (gumb "Admin" v navigaciji, viden samo prijavljenim
urednikom in administratorjem).

---

## 1. Kako naložiti dokument

1. Pojdi na **Admin → Dokumenti** (`/admin/documents`).
2. Klikni **"Nov dokument"**.
3. Izpolni obrazec:
   - **Naslov** — obvezen, prikazan v seznamu dokumentov in iskanju.
   - **Opis** — neobvezen, kratka opomba o vsebini.
   - **Kategorija** — izberi obstoječo ali ustvari novo (glej spodaj, razdelek 5).
   - **Datoteka** — naloži **PDF** (drugi formati niso podprti za samodejno predogled/OCR).
   - **Enota** — komu je dokument namenjen: *Knjižnica*, *Gledališče* ali *Oboje*. Vpliva na to,
     kdo prejme e-mail obvestilo (če je vklopljeno) in v katerih filtrih se dokument prikaže.
   - **Datum objave** — kdaj naj se dokument šteje kot objavljen (lahko nastaviš tudi za nazaj).
   - **Samo za interno uporabo** — če je obkljukano, dokument NI viden neprijavljenim
     obiskovalcem javnega dela strani (samo prijavljenim uporabnikom).
   - **Obvesti zaposlene** — če je obkljukano, se ob shranitvi pošlje e-mail obvestilo
     ustrezni enoti (glej razdelek 3).
4. Klikni **"Shrani"**.

### Kaj se zgodi v ozadju (OCR + predogled)

Po naložitvi PDF-ja se v ozadju (lahko traja od nekaj sekund do ~1 minute, odvisno od
velikosti datoteke) samodejno zgodi:

- **Sličica (thumbnail)** — slika prve strani PDF-ja, prikazana v seznamu dokumentov.
- **OCR (prepoznava besedila)** — če je PDF skeniran dokument (slika, ne pravo besedilo),
  Tabla samodejno prepozna besedilo na sliki (podpira slovenščino in madžarščino). To besedilo
  postane **iskljivo** — uporabniki ga lahko najdejo prek iskalnika, čeprav gre za skenirano
  sliko.

Ni potrebno ničesar dodatno narediti — oboje teče samodejno. Če sličica po nekaj minutah še ni
vidna, osveži stran; če je še vedno ni, je verjetno datoteka poškodovana ali je obdelava
spodletela (preveri PDF, da se normalno odpre v drugem programu).

**Pomembno:** Tabla sprejema samo `.pdf` datoteke. Word/Excel/slike (.docx, .xlsx, .jpg) je
treba najprej pretvoriti v PDF (npr. "Print to PDF" ali Word/Excel "Shrani kot PDF").

---

## 2. Kako urediti telefonski imenik

Telefonski imenik je sestavljen iz **oseb** (`/admin/persons`) in njihovih **telefonskih
številk**. Vsaka oseba je lahko vezana na lokacijo (npr. konkretno enoto/oddelek).

1. Pojdi na **Admin → Osebe** (`/admin/persons`).
2. Za urejanje obstoječe osebe klikni **"Uredi"** ob njenem imenu; za novo osebo klikni
   **"Nova oseba"**.
3. Izpolni:
   - **Ime / Priimek** — priimek je obvezen.
   - **Naziv delovnega mesta** — prikazan pod imenom v imeniku.
   - **E-pošta** — neobvezna, prikazana kot povezava (klik odpre e-poštni program).
   - **Lokacija** — izbira oddelka/enote (vpliva na razvrstitev v dvostolpčnem prikazu
     imenika na domači strani — Knjižnica/SIKLND levo, NOE desno).
   - **Aktivna** — če odkljukaš, oseba izgine iz javnega imenika (a zapis ostane v bazi —
     uporabno za začasno odsotnost ali ob odhodu iz službe brez takojšnjega brisanja).
4. **Telefonske številke** — znotraj istega obrazca lahko dodaš eno ali več številk
   (notranja/interna, zunanja). Klikni **"Dodaj telefonsko številko"** za dodatno vrstico,
   ali krativec ob obstoječi za odstranitev.
5. Klikni **"Shrani"**.

Sprememba je takoj vidna v javnem imeniku (`/persons`) in na domači strani.

---

## 3. Kako objaviti obvestilo (z e-mail obvestilom enoti)

1. Pojdi na **Admin → Obvestila** (`/admin/announcements`).
2. Klikni **"Novo obvestilo"**.
3. Izpolni:
   - **Naslov** in **Vsebina** — besedilo obvestila.
   - **Enota** — komu je obvestilo namenjeno: *Knjižnica*, *Gledališče* ali *Oboje*.
   - **Datum objave** — od kdaj je obvestilo vidno.
   - **Datum preteka** — neobvezen; po tem datumu obvestilo samodejno izgine s strani.
   - **Pripni na vrh** — če odkljukaš, se obvestilo prikaže poudarjeno na vrhu domače strani
     (uporabi za res nujna obvestila — npr. zaprtje, izpad sistema).
4. Klikni **"Shrani"**.

### E-mail obvestilo

Za **obvestila** se e-mail NE pošilja samodejno — obvestila so namenjena prikazu na intranetu.

Za **dokumente** pa, če pri nalaganju dokumenta obkljukaš **"Obvesti zaposlene"**, se ob
shranitvi pošlje skupinski e-mail (z BCC, torej prejemniki ne vidijo drug drugega) vsem
zaposlenim ustrezne enote:

| Enota dokumenta | Kdo prejme e-mail                          |
|------------------|---------------------------------------------|
| Knjižnica        | zaposleni knjižnice + uprava                |
| Gledališče       | zaposleni gledališča + uprava               |
| Oboje            | vsi zaposleni (obe enoti + uprava)          |

E-mail se pošlje samo enkrat, ob shranitvi novega dokumenta z obkljukano možnostjo. Če dokument
kasneje urejaš, ponovno obvestilo ni poslano (razen če ponovno obkljukaš in shraniš — preveri
pred shranjevanjem, da se izogneš podvojenim obvestilom).

---

## 4. Kako preveriti analitiko

Dostopno samo **administratorju** (ne uredniku).

1. Pojdi na **Admin → Analitika** (`/admin/analytics`).
2. Na voljo so:
   - **Filtri** — po datumu, uporabniku, IP naslovu, ali besedilno iskanje (po OS, brskalniku,
     uporabniškem imenu).
   - **OS statistika** — pregled, s kakšnimi napravami/operacijskimi sistemi ljudje dostopajo.
   - **Seje (obiski)** — kdo, kdaj, s kakšne naprave/IP-ja je obiskal Tablo.
   - **Dogodki** — podrobnejši dogodki (npr. ogled strani).
3. Pojdi na **Admin → Branjenost dokumentov** (`/admin/document_popularity`) za pregled, kateri
   dokumenti so najbolj brani:
   - Filter po obdobju: zadnji teden / zadnji mesec / od začetka.
   - Tabela: dokument, število ogledov, število različnih bralcev, zadnji ogled.
4. Pojdi na **Admin → Zgodovina dokumentov** (`/admin/document_audits`) za pregled, kdo je kdaj
   kaj spremenil na posameznem dokumentu (naslov, kategorija, datoteka ipd.). Lahko tudi
   neposredno na strani posameznega dokumenta klikneš gumb **"Zgodovina"**.

---

## Dodatno — pogosta vprašanja

**Q: Naložil sem PDF, a sličica se ne prikaže.**
A: Počakaj minuto in osveži stran. Če se še vedno ne prikaže, preveri, da je datoteka veljaven
PDF (odpri jo v drugem programu). Poskusi ponovno naložiti.

**Q: Kako spremenim vrstni red kategorij dokumentov?**
A: Admin → Kategorije dokumentov → uredi posamezno kategorijo → polje "Vrstni red" (manjša
številka = prej v seznamu).

**Q: Kako odstranim osebo iz imenika, brez da izbrišem zgodovino?**
A: Uredi osebo in odkljukaj "Aktivna" — oseba izgine iz javnega imenika, a zapis (in zgodovina)
ostane v bazi.

**Q: Kdo lahko dostopa do admin strani?**
A: Samo uporabniki z vlogo *Urednik* ali *Administrator*. Vloge se sinhronizirajo iz aplikacije
Prisotnost — če nekdo potrebuje dostop, ga je treba urediti tam.

**Q: Kdo lahko vidi analitiko in zgodovino sprememb?**
A: Samo *Administrator* (ne urednik) — gre za bolj občutljive podatke (IP naslovi, sledenje).

---

*Ta priročnik se nanaša na Tabla v0.1.0+. Za tehnična vprašanja ali težave se obrni na
razvijalca (Dejan Vučko).*
