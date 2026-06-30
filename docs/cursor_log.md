# Dnevnik tehničnih sej (Cursor Log)

Podroben tehnični dnevnik sej — kontekst, analiza, spremembe kode in odločitve za vsako
zaključeno nalogo ali popravek. Dopolnjuje `CHANGELOG.md` (ki je strnjen pregled funkcij po
verzijah); ta dnevnik hrani "zakaj" in podrobnosti izvedbe.

Vnosi so kronološki (najstarejši zgoraj, novi se pripenjajo na dno).

## [2026-06-30 — Izdaja v1.0.0, README in dvojni log]

### Kontekst

Tabla je v produkciji in predana v uporabo. Čas za uradno označitev verzije, pravi README
(prej privzeti Rails stub) in vzpostavitev dvojnega beleženja (CHANGELOG + cursor_log) po
vzoru Delovodnika.

### Spremembe

- **`README.md`** — napisan pravi README: tehnologija, razvojno okolje, avtentikacija prek
  Prisotnost API, dokumentacija, konvencije, deployment, in razdelek "Pogoste pasti"
  (dodajanje gema, master.key, initializerji).
- **`config/initializers/constants.rb`** — `BASE_VERSION` `0.1.0` → `1.0.0`.
- **`CHANGELOG.md`** — `[Unreleased]` zaprt kot `[1.0.0] - 2026-06-30`; nad njim dodan nov
  prazen `[Unreleased]` za prihodnje vnose; dodana referenca na Keep a Changelog + SemVer.
- **`.cursor/rules/01_global.mdc`** — dodano pravilo o dvojnem logu: nove spremembe v
  `[Unreleased]` v CHANGELOG, podroben tehnični povzetek v `docs/cursor_log.md`.
- **`docs/cursor_log.md`** — ta datoteka (nova).

### Lekcija zabeležena (v README)

Dodajanje gema v tem projektu: ker `docker-compose.yml` nima bundle volumna, je po `bundle
install` treba preveriti, da je gem v `specs` (ne le `DEPENDENCIES`) v `Gemfile.lock`, nato
`docker compose build` + `up -d`. Sprožilo: `LoadError: cannot load such file -- rqrcode`
zaradi delno resolviranega Gemfile.lock (gem v DEPENDENCIES, a ne v specs).
