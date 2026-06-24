#!/usr/bin/env bash
set -e

git pull
docker compose down
docker compose build
docker compose up -d

# Primary migracije (ne-destruktivno: doda samo nove migracije)
docker compose run --rm rails_app bin/rails db:migrate

# Solid Queue/Cache/Cable tabele — naloži SAMO če manjkajo (varno, ne briše podatkov).
# Potrebno, ker te tabele niso v db/migrate, ampak v ločenih *_schema.rb datotekah.
docker compose run --rm rails_app bin/rails runner '
  conn = ActiveRecord::Base.connection
  needs_load = !conn.table_exists?("solid_queue_jobs") ||
               !conn.table_exists?("solid_cache_entries") ||
               !conn.table_exists?("solid_cable_messages")
  if needs_load
    puts "Solid tabele manjkajo — nalagam sheme..."
    load Rails.root.join("db/queue_schema.rb")
    load Rails.root.join("db/cache_schema.rb")
    load Rails.root.join("db/cable_schema.rb")
    puts "Solid sheme naložene."
  else
    puts "Solid tabele že obstajajo — preskačem."
  end
'

# Tailwind CSS (watch ne deluje na macOS Docker — glej docker-compose.yml)
docker compose exec rails_app bin/rails tailwindcss:build
