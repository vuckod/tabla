# frozen_string_literal: true

# Hash revizije: v produkciji (Kamal) iz KAMAL_REVISION env, lokalno iz git.
git_hash = ENV["KAMAL_REVISION"].presence
git_hash ||= begin
  `git rev-parse --short HEAD 2>/dev/null`.strip
rescue StandardError
  nil
end
git_hash = nil if git_hash.blank?

BASE_VERSION = "1.0.0"

short_hash = git_hash.present? ? git_hash[0..6] : nil
TABLA_VERSION = short_hash.present? ? "#{BASE_VERSION} (#{short_hash})" : BASE_VERSION

# Datum in čas zagona procesa (ob deployu / restartu strežnika).
RELEASE_DATE = Time.current.strftime("%d. %m. %Y %H:%M")
