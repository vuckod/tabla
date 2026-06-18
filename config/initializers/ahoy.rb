# Ahoy — analitika obiskov in dogodkov (enako kot v Delovodniku)
class Ahoy::Store < Ahoy::DatabaseStore
end

Ahoy.api = false
Ahoy.server_side_visits = :when_needed
Ahoy.visit_duration = 4.hours
Ahoy.geocode = false
