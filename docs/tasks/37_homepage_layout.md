# Naloga 37: Domača stran — preureditev v tri vrstice (dokumenti + ponovljene povezave)

## Cilj
Preuredi domačo stran tako, da je blok zunanjih povezav viden tudi ob brskanju dokumentov.
Struktura po vrsticah (lg breakpoint):

| Vrstica | Postavitev (lg:grid-cols-12)                                    |
|---------|------------------------------------------------------------------|
| 1       | Nujna obvestila — polna širina (12), samo če obstajajo           |
| 2       | Imenik (8) + Aplikacije (2) + Povezave (2)                       |
| 3       | Dokumenti (10) + Povezave (2, **ponovitev** — samo na desktopu)  |

Blok povezav se na desktopu pojavi DVAKRAT — vsakič kot del svoje vrstice. Na mobilnem
(< lg) se drugi pojav SKRIJE, da se ne ponavlja (na mobilnem je vse navpično).

## Stanje
Trenutno (`app/views/home/index.html.erb`):
- Vrstica 1: obvestila ✓
- Vrstica 2: imenik (8) + aplikacije (2) + povezave (2) ✓ (ostane enako)
- Vrstica 3: dokumenti polna širina ← treba na 10 + povezave (2)

## Koraki

### 1. Spremeni vrstico 3 v `home/index.html.erb`
Zamenjaj:
```erb
<div>
  <%= render "home/documents", ... %>
</div>
```
z:
```erb
<%# Vrstica 3: dokumenti (10) + povezave (2, ponovitev — samo na desktopu) %>
<div class="grid grid-cols-1 lg:grid-cols-12 gap-4">
  <div class="lg:col-span-10">
    <%= render "home/documents",
        document_categories: @document_categories,
        selected_category_id: @selected_category_id,
        documents: @documents,
        pagy: @pagy %>
  </div>
  <div class="hidden lg:block lg:col-span-2">
    <%= render "home/external_links", external_link_categories: @external_link_categories %>
  </div>
</div>
```

Ključno: `hidden lg:block` na drugem pojavu povezav — skrit na < lg, da se NE ponavlja na
mobilnem (kjer je vse navpično in se prvi pojav v vrstici 2 že prikaže).

### 2. Vizualna preverba znotraj documents bloka
Ker dokumentni blok ne bo več polna širina (10 stolpcev namesto 12), preveri, ali se znotraj
`home/_documents.html.erb` in `documents/_list.html.erb` postavitev pravilno prilagodi:
- **Filter chips** (kategorije) — `flex flex-wrap`, naj ostanejo na vrhu
- **Document row** — flex z thumbnailom + naslovom + gumbi; preveri, da se na ozkih dokumentnih
  stolpcih (lg:col-span-10 je še vedno širok) ne razbije; če se kaj razbije, sproti popravi
- **Paginacija** — centrirana (mt-6 flex justify-center), ostane v redu

POZOR turbo_frame: `documents_list` turbo frame je znotraj `_list.html.erb` partiala, sprememba
zunanjega layouta ga ne pokvari. Paginacija + filter chips delujejo naprej.

### 3. Vizualna preverba povezavnega bloka v 3. vrstici
Blok povezav (drugi pojav) bo v vrstici 3 ob dokumentih. Ker dokumentni blok ima paginacijo s
~25 dokumenti, bo verjetno visok (~700-900px). Povezave imajo `max-h-[44rem]` (~704px) +
scroll, kar je primerno.

Razmisli o `lg:sticky lg:top-4` na drugem pojavu povezav — da bi ostal viden ob scrollanju
dokumentov. To je opcijska izboljšava, ne osnovni zahtevek. Lahko dodaš kot komentar/možnost,
NE implementiraj v tem prehodu (najprej osnovna preureditev, sticky kasneje, če bo želeno).

### 4. Konsistentnost gridov
Obe vrstici (2 in 3) imata isto `grid grid-cols-1 lg:grid-cols-12 gap-4` — vertikalna linija
povezav je v obeh vrsticah v istem stolpcu (col 11-12). Vizualno usklajeno.

## Reference
- `app/views/home/index.html.erb` (edina datoteka, ki jo spreminjamo)
- `app/views/home/_external_links.html.erb` (renderira se dvakrat, brez sprememb)
- `app/views/home/_documents.html.erb` + `documents/_list.html.erb` (brez sprememb v vsebini,
  samo vizualna preverba zaradi ožje širine)

## Acceptance criteria
- [ ] Vrstica 2 ostane (imenik 8 + aplikacije 2 + povezave 2)
- [ ] Vrstica 3: dokumenti col-span-10 + povezave col-span-2 z `hidden lg:block`
- [ ] Na lg+ ekranih: blok povezav viden dvakrat (vsakič v svoji vrstici)
- [ ] Na < lg ekranih: blok povezav viden ENKRAT (samo v vrstici 2; drugi pojav skrit)
- [ ] Dokumentni blok se vizualno ne razbije v ožjem stolpcu (filter, vrstice, paginacija)
- [ ] Turbo frame `documents_list` deluje (filter + paginacija znotraj)
- [ ] Obvestila ostanejo polna širina
- [ ] `bin/rails tailwindcss:build` ni potreben (vsi razredi že obstajajo)

## Test
1. Desktop (≥ lg, 1024px+): vrstici 2 in 3 imata vsaka svoj blok povezav (vertikalno
   usklajenо na desni)
2. Mobilni (< lg): blok povezav viden samo enkrat (v vrstici 2); na vrstici 3 samo dokumenti
3. Filtriraj dokumente po kategoriji → paginacija deluje, deluje znotraj turbo frame
4. Klik na predogled/prenos dokumenta → običajno delovanje

## Out of scope
- Sticky positioning povezav (opcija za prihodnost)
- Spreminjanje vsebine blokov (samo postavitev)
- Spreminjanje vrstice 2 in obvestil
