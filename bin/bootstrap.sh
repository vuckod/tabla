#!/bin/bash
# ============================================================================
# Bootstrap skripta za Tabla (Intranet KL-KL)
# Poženi ENKRAT znotraj Docker kontejnerja:
#   docker compose build
#   docker compose run --rm rails_app bash bin/bootstrap.sh
# ============================================================================

set -e

echo "=== 1/5: Generiranje Rails projekta ==="
# --force: prepiše obstoječe datoteke (Gemfile, etc.)
# --database=postgresql: PostgreSQL adapter
# --css=tailwind: Tailwind CSS
# --skip-jbuilder: ne rabimo JSON builderja
# --skip-test: bomo dodali teste pozneje
# --name=tabla: ime aplikacije
rails new . \
  --force \
  --database=postgresql \
  --css=tailwind \
  --skip-jbuilder \
  --skip-test \
  --name=tabla

echo "=== 2/5: Dodajanje gemov specifičnih za Tabla ==="
# Dodamo geme, ki jih rails new ne vključi
cat >> Gemfile << 'GEMS'

# === Tabla-specifični gemi ===
# Avtorizacija
gem "pundit"

# Analitika obiskov
gem "ahoy_matey", "~> 5.4"

# Revizijska sled (spremembe dokumentov, kontaktov)
gem "audited", "~> 5.6"

# Iskanje (deljena instanca z Delovodnikom)
gem "meilisearch-rails"

# Paginacija
gem "pagy", "~> 9.3"

# OCR
gem "rtesseract"

# CSV obdelava
gem "csv"

# Pregled poslane e-pošte v razvoju
group :development do
  gem "letter_opener_web"
end
GEMS

echo "=== 3/5: Bundle install ==="
bundle install

echo "=== 4/5: Solid Queue / Cache / Cable setup ==="
# Solid Queue, Cache in Cable so vključeni v Rails 8.1 privzeto

echo "=== 5/5: Tailwind CSS build ==="
bin/rails tailwindcss:install 2>/dev/null || true

echo ""
echo "============================================="
echo "  Bootstrap končan!"
echo ""
echo "  Naslednji koraki:"
echo "  1. Izhod iz kontejnerja (exit)"
echo "  2. Javi Claudu, da prilagodi generirane datoteke"
echo "     (database.yml, routes, initializers, ...)"
echo "  3. docker compose run --rm rails_app bin/rails db:create"
echo "  4. git add -A && git commit -m 'Rails 8.1.2 skeleton'"
echo "============================================="
