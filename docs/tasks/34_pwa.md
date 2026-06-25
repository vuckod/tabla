# Naloga 34: PWA (Progressive Web App) — namestljiva aplikacija

## Cilj
Tabla naj bo namestljiva kot PWA (kot Delovodnik) — "Dodaj na začetni zaslon" na mobilnih,
namestitev na Android/Chrome. Uporabi vzorec iz Delovodnika: manifest + apple meta + ikone +
minimalni service worker. Ikone (192 + 512) pripravi uporabnik.

## Stanje
- Routes `manifest` + `service-worker` že obstajata (✓)
- `app/views/pwa/manifest.json.erb` — privzeti Rails stub (placeholder "red" barve, ena ikona)
- `app/views/pwa/service-worker.js` — zakomentiran stub (treba zamenjati)
- `application.html.erb` head — NIMA manifest linka, NIMA theme-color, NE registrira SW
- `public/` — ima samo `icon.png` + `icon.svg`; manjkata `icon-192.png` + `icon-512.png`

## Vzorec iz Delovodnika (deluje)
- `delovodnik_rails/app/views/pwa/manifest.json.erb`
- `delovodnik_rails/app/views/pwa/service-worker.js.erb` (minimal: skipWaiting + clients.claim)
- `delovodnik_rails/app/helpers/application_helper.rb` → `pwa_manifest` helper
- `delovodnik_rails/public/icon-192.png`, `icon-512.png`

## Koraki

### 1. manifest.json.erb — pravilne vrednosti
Zamenjaj placeholder vsebino. Predlog:
```erb
{
  "short_name": "Tabla",
  "name": "Tabla — Intranet KKC Lendava",
  "description": "Intranet Knjižnice Lendava — dokumenti, imenik, povezave, obvestila.",
  "display": "standalone",
  "start_url": "/",
  "scope": "/",
  "theme_color": "#1e1b4b",
  "background_color": "#f8fafc",
  "icons": [
    { "src": "/icon-192.png", "type": "image/png", "sizes": "192x192" },
    { "src": "/icon-512.png", "type": "image/png", "sizes": "512x512" },
    { "src": "/icon-512.png", "type": "image/png", "sizes": "512x512", "purpose": "maskable" }
  ]
}
```
POZOR: barve niso več "red" — `theme_color` indigo (#1e1b4b, ujema se z aplikacijo),
`background_color` svetlo siva (#f8fafc).

### 2. service-worker — minimalni delujoč (zamenjaj stub)
Zamenjaj zakomentirano vsebino `app/views/pwa/service-worker.js` z minimalnim SW (kot Delovodnik):
```js
// Minimalni service worker: skipWaiting + clients.claim (posodobi se ob vsakem deployu).
self.addEventListener("install", (event) => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});
```
Brez fetch/cache handlerja (kot Delovodnik) — ne kešira (vsebina je dinamična, prijava potrebna).
`skipWaiting` + `clients.claim` zagotovita, da se SW posodobi ob deployu.

### 3. Helper pwa_manifest (kopiraj iz Delovodnika)
V `app/helpers/application_helper.rb` dodaj:
```ruby
# Povezava na dinamični manifest (rails/pwa#manifest).
def pwa_manifest
  tag.link(rel: "manifest", href: pwa_manifest_path(format: :json))
end
```

### 4. application.html.erb head — poveži manifest, theme-color, registriraj SW
Dodaj v `<head>` (Tabla že ima apple-mobile-web-app-capable + application-name):
```erb
<meta name="theme-color" content="#1e1b4b">
<%= pwa_manifest %>
```
In registriraj service worker (na koncu head ali pred </body>). Ker Tabla uporablja importmap +
Turbo, dodaj v `app/javascript/application.js` (ali inline script v layout):
```js
// Registracija service workerja (PWA namestljivost na Android/Chrome).
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker").catch((e) => {
      console.warn("SW registracija ni uspela:", e);
    });
  });
}
```
POZOR pot: route je `get "service-worker" => "rails/pwa#service_worker"`, torej registriraj
`/service-worker` (brez .js). Scope mora biti "/" — ker SW streže s korena, je scope OK.

### 5. Ikone (UPORABNIK pripravi)
Potrebni datoteki v `public/`:
- `icon-192.png` (192×192) — domači zaslon
- `icon-512.png` (512×512) — splash + maskable
Uporabnik pripravi ikono. POZOR maskable: ikona naj ima dovolj "varnega območja" (padding ~10%
okoli logotipa), da je ob maskiranju (krog/zaobljen kvadrat na Androidu) logo viden. Če uporabnik
da samo eno veliko ikono, lahko 512 uporabimo za oboje, a 192 je priporočljiva ločeno.

Obstoječi `public/icon.png` + `icon.svg` ostaneta (favicon). apple-touch-icon naj kaže na
192 (ali obstoječ icon.png, če je dovolj velik).

### 6. apple-touch-icon (preveri/posodobi)
Tabla head ima `<link rel="apple-touch-icon" href="/icon.png">`. Če je icon.png 512×512, je OK.
Lahko posodobiš na `/icon-192.png` za doslednost. iOS uporablja apple-touch-icon za domači zaslon.

## Reference
- `delovodnik_rails/app/views/pwa/*` — vzorec manifest + SW
- `delovodnik_rails/app/helpers/application_helper.rb` → `pwa_manifest`
- `delovodnik_rails/public/icon-192.png`, `icon-512.png` — velikosti
- `tabla/app/views/layouts/application.html.erb` — head (dodaj manifest + theme-color + SW reg)
- `tabla/config/routes.rb` — PWA routes (že obstajata)

## Acceptance criteria
- [ ] manifest.json.erb pravilen (ime, opis, indigo barve, 192+512+maskable ikone)
- [ ] service-worker minimalni delujoč (skipWaiting + clients.claim)
- [ ] `pwa_manifest` helper dodan
- [ ] Head: theme-color meta + manifest link + SW registracija
- [ ] Ikone icon-192.png + icon-512.png v public/ (uporabnik doda)
- [ ] Chrome DevTools → Application → Manifest: brez napak, ikone naložene
- [ ] Chrome: "Install" / Android: "Dodaj na začetni zaslon" deluje
- [ ] iOS Safari: Share → "Dodaj na začetni zaslon" → odpre se standalone
- [ ] `bin/tailwind-build` ni potreben (ni Tailwind sprememb)

## Test
1. Deploy (PWA potrebuje HTTPS — produkcija i.kl-kl.si ima ✓)
2. Chrome DevTools → Application → Manifest → preveri ime, barve, ikone (brez napak)
3. Chrome → naslovna vrstica → ikona za namestitev → namesti
4. Android Chrome → meni → "Dodaj na začetni zaslon"
5. iOS Safari → Share → "Dodaj na začetni zaslon" → odpri → standalone (brez Safari UI)

POZOR: PWA namestljivost se testira NA PRODUKCIJI (HTTPS). Localhost deluje za manifest pregled,
a polna namestitev rabi HTTPS.

## Out of scope
- Offline način / caching (minimalni SW ne kešira — kot Delovodnik)
- Web Push obvestila (zakomentiran primer ostane za prihodnost)
- Splash screens za vse iOS velikosti (apple-touch-icon zadošča)
