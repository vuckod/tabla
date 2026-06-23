#!/usr/bin/env bash
set -e

git pull
docker compose down
docker compose build
docker compose up -d
docker compose run --rm rails_app bin/rails db:migrate
docker compose exec rails_app bin/rails tailwindcss:build
