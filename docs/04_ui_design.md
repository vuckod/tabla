# UI prenova in končni izgled — Intranet (tabla) KKC Lendava

Ta dokument je krovni načrt za prenovo postavitve in izgleda. Posamezne izvedbene naloge
so v `docs/tasks/13_*` do `docs/tasks/18_*`. Cursor naj bere ta dokument za kontekst,
nato izvaja posamezne task datoteke po vrsti.

## Ime aplikacije

- **Polno ime:** "Intranet (tabla) KKC Lendava — Lendvai KKK"
- Uporabi v: `<title>`, header logo/naziv, `config/application.rb` (kjer relevantno)
- Madžarski podnaslov "Lendvai KKK" naj bo manjši/sekundaren ob slovenskem nazivu

## Globalna postavitev (layout)

Na širokih zaslonih naj vsebina zavzema **~90% širine** (`max-w-[90%]` ali primeren
container, NE ozki `max-w-7xl`). Na mobilnem polna širina z manjšimi robovi.

### Mreža blokov (od zgoraj navzdol)

```
┌──────────────────────────────────────────────────────────────────┐
│  HEADER: naziv + iskalnik + dark mode + uporabnik/odjava           │
├──────────────────────────────────────────────────────────────────┤
│  NUJNA OBVESTILA (prikazano samo če obstaja aktivno obvestilo)     │
│  ┌────────────────────────────┬───────────┬───────────┐          │
│  │ (4/8) obvestila — široko    │ (1/2)     │ (1/2)     │          │
│  │                            │           │           │          │
│  ├────────────────────────────┤  INTERNE  │  ZUNANJE  │          │
│  │ (4/8) TELEFONSKI IMENIK     │  APP      │  POVEZAVE │          │
│  │ tabela: interna/zunanja/    │  (Prisot, │  (IZUM,   │          │
│  │ naziv mesta/enota           │  Delovod, │  ob\u010dine,  │          │
│  │                            │  ShPoint) │  NUK...)  │          │
│  └────────────────────────────┴───────────┴───────────┘          │
├──────────────────────────────────────────────────────────────────┤
│  DOKUMENTI (širok blok čez celo širino)                            │
│  [filter značk] [najnovejši na vrhu]                               │
└──────────────────────────────────────────────────────────────────┘
```

Razmerja stolpcev zgornjega dela: **8:2:2** (Tailwind 12-stolpčna mreža →
`lg:col-span-8`, `lg:col-span-2`, `lg:col-span-2`). Na mobilnem se vse zloži v en stolpec
(vertikalno): obvestila → imenik → interne app → zunanje povezave → dokumenti.

Telefonski imenik je v **istem levem širokem stolpcu** pod nujnimi obvestili (oba sta
v 8/12 širine), interne in zunanje povezave sta desno (vsak 2/12).

## Barvna shema — živahni bloki

Vsak blok ima izrazito, živo barvo (ne pastele). Uporabi Tailwind 400-600 odtenke za
ozadja blokov, z belim/temnim besedilom za kontrast. Predlog dodelitve:

| Blok                     | Barva (light)              | Barva (dark)                |
| ------------------------- | -------------------------- | --------------------------- |
| Nujna obvestila          | `bg-red-500` / `amber-400` | `bg-red-600` / `amber-600`  |
| Telefonski imenik         | `bg-yellow-400`            | `bg-yellow-600`             |
| Interne aplikacije        | `bg-green-500`             | `bg-green-700`              |
| Zunanje povezave          | `bg-blue-500`              | `bg-blue-700`               |
| Dokumenti                 | `bg-indigo-500` ali nevtralno bel z barvnimi značkami |

Glave blokov naj bodo še bolj nasičene (npr. `bg-yellow-500` glava nad `bg-yellow-100`
telesom), z dobro berljivim kontrastom. Vedno dodaj `dark:` variante.

Pomembno: kljub živim barvam mora biti besedilo berljivo (WCAG kontrast). Za rumeno
ozadje uporabi temno besedilo (`text-slate-900`), za modro/zeleno/rdečo belo
(`text-white`).

## Iskalnik

V headerju globalni iskalnik. V tej fazi naj išče **po dokumentih** (naslov + opis;
OCR vsebina pride z Meilisearch nalogo pozneje). Polje + Enter (brez auto-submit za
globalni iskalnik, skladno z `.cursor/rules/03_hotwire_frontend.mdc`).

## Povzetek sprememb modela (glej posamezne naloge za podrobnosti)

1. **Announcement** (NOV model) — nujna obvestila z enoto in samodejnim potekom (7 dni)
2. **DocumentCategory → značke** — obstoječi model ostane, samo razširimo seed/uporabo
   (ena značka na dokument, prek obstoječega `document_category_id`); dodamo `color` za
   barvno značko (stolpec `color` že obstaja v shemi)
3. **PhoneNumber** — razširimo prikaz: imenik prikaže tako osebe (z imenom) kot mesta
   (brez osebe, samo `label` = naziv mesta). Model že podpira oboje (person opcijski).

## Vrstni red nalog

1. `13_announcements.md` — model + CRUD + prikaz nujnih obvestil
2. `14_layout_redesign.md` — nova mreža blokov, 90% širina, ime aplikacije
3. `15_directory_table.md` — tabelaričen imenik (interna/zunanja/mesto/enota)
4. `16_links_blocks.md` — interne app + zunanje povezave kot živahna bloka
5. `17_documents_tags.md` — značke, filter, najnovejši na vrhu
6. `18_search.md` — globalni iskalnik po dokumentih

## Reference
- `docs/00_overview.md` — splošna arhitektura (posodobi UI sekcijo po tej prenovi)
- `docs/01_data_model.md` — podatkovni model
- Priložen originalni PHP screenshot (začetek projekta) — barvna referenca živahnih blokov
