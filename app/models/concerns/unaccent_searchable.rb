# frozen_string_literal: true

# Skupna logika za iskanje, ki ignorira akcente: PostgreSQL +unaccent+ in preslikava znakov.
# Preneseno iz Delovodnika.
# Razredne metode: +where_terms_match+ (več besed, AND), +where_single_term_or_match+ (en niz, OR po stolpcih).
module UnaccentSearchable
  extend ActiveSupport::Concern

  TRIGRAM_GLOBAL_SEARCH_THRESHOLD = 0.18

  GIN_TRIGRAM_COLUMNS_BY_TABLE = {
    "documents" => %w[title description ocr_text].freeze
  }.freeze

  SQLITE_FOLD_PAIRS = [
    %w[á a], %w[à a], %w[â a], %w[ä a], %w[ã a], %w[å a], %w[ā a], %w[ă a], %w[ą a],
    %w[ç c], %w[ć c], %w[č c],
    %w[ď d], %w[đ d],
    %w[è e], %w[é e], %w[ê e], %w[ë e], %w[ē e], %w[ė e], %w[ę e], %w[ě e],
    %w[ì i], %w[í i], %w[î i], %w[ï i], %w[ī i], %w[į i], %w[ı i],
    %w[ñ n], %w[ń n], %w[ň n],
    %w[ò o], %w[ó o], %w[ô o], %w[õ o], %w[ö o], %w[ō o], %w[ő o], %w[ø o],
    %w[ř r],
    %w[ś s], %w[š s],
    %w[ť t], %w[ţ t], %w[ț t],
    %w[ù u], %w[ú u], %w[û u], %w[ü u], %w[ū u], %w[ů u], %w[ű u], %w[ų u],
    %w[ý y], %w[ÿ y],
    %w[ź z], %w[ž z], %w[ż z],
    %w[ß s], %w[ł l], %w[þ t], %w[ð d]
  ].freeze

  class << self
    def postgresql_adapter?(connection)
      connection.adapter_name.match?(/postgres|postgis/i)
    end

    def postgresql_set_trigram_word_similarity_threshold!(connection, threshold: TRIGRAM_GLOBAL_SEARCH_THRESHOLD, local: false)
      raise ArgumentError, "PostgreSQL required" unless postgresql_adapter?(connection)
      scope = local ? "LOCAL " : ""
      connection.execute("SET #{scope}pg_trgm.word_similarity_threshold = #{connection.quote(threshold.to_f)}")
    end

    def postgresql_trigram_normalized_query_sql_literal(connection, raw_query)
      quoted = connection.quote(raw_query.to_s)
      "lower(unaccent(#{quoted}))"
    end

    def gin_trigram_indexed_column_ref?(column_ref)
      table, column = column_ref.to_s.split(".", 2)
      return false if table.blank? || column.blank?
      GIN_TRIGRAM_COLUMNS_BY_TABLE.fetch(table, []).include?(column)
    end

    def postgresql_trigram_column_sql_for_operator(column_ref)
      ref = column_ref.to_s
      if gin_trigram_indexed_column_ref?(ref)
        "COALESCE(#{ref}, '')"
      else
        "lower(unaccent(COALESCE(#{ref}, '')))"
      end
    end

    def postgresql_trigram_word_similarity_operator_match_sql(connection, column_ref, raw_query)
      query_sql = postgresql_trigram_normalized_query_sql_literal(connection, raw_query)
      column_sql = postgresql_trigram_column_sql_for_operator(column_ref)
      "#{query_sql} <% #{column_sql}"
    end

    def postgresql_trigram_any_column_operator_match_sql(connection, column_refs, raw_query)
      raise ArgumentError, "PostgreSQL required" unless postgresql_adapter?(connection)
      refs = Array(column_refs).map(&:to_s).uniq.compact_blank
      raise ArgumentError, "column_refs required" if refs.blank?
      parts = refs.map { |c| postgresql_trigram_word_similarity_operator_match_sql(connection, c, raw_query) }
      return parts.first if parts.one?
      "(#{parts.join(' OR ')})"
    end

    def postgresql_trigram_word_similarity_sql_literal(connection, column_ref, raw_query)
      quoted = connection.quote(raw_query.to_s)
      <<~SQL.squish
        word_similarity(
          lower(unaccent(#{quoted})),
          lower(unaccent(COALESCE(#{column_ref}, '')))
        )
      SQL
    end

    def postgresql_trigram_greatest_score_sql(connection, column_refs, raw_query)
      raise ArgumentError, "PostgreSQL required" unless postgresql_adapter?(connection)
      refs = Array(column_refs).map(&:to_s).uniq.compact_blank
      raise ArgumentError, "column_refs required" if refs.blank?
      parts = refs.map { |c| postgresql_trigram_word_similarity_sql_literal(connection, c, raw_query) }
      return parts.first if parts.one?
      "GREATEST(#{parts.join(', ')})"
    end

    def where_terms_match(scope, raw_query, column_refs, bind_prefix: "ua")
      sql, binds = where_terms_match_sql_and_binds(scope.connection, raw_query, column_refs, bind_prefix: bind_prefix)
      return scope if sql.blank?
      scope.where(sql, binds)
    end

    def where_single_term_or_match(scope, raw_term, column_refs, bind: :pat)
      q = raw_term.to_s.strip
      return scope if q.blank?
      raise ArgumentError, "column_refs required" if column_refs.blank?
      conn = scope.connection
      sql, binds = single_term_or_match_sql_and_binds(conn, q, column_refs, bind: bind)
      scope.where(sql, binds)
    end

    def single_term_or_match_sql_and_binds(connection, raw_term, column_refs, bind: :pat)
      q = raw_term.to_s.strip
      return [nil, {}] if q.blank?
      raise ArgumentError, "column_refs required" if column_refs.blank?

      if postgresql_adapter?(connection)
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(q)}%"
        cols = column_refs.map do |c|
          "lower(unaccent(COALESCE(#{c}, ''))) ILIKE lower(unaccent(:#{bind}))"
        end.join(" OR ")
        [cols, { bind => pattern }]
      else
        folded = sqlite_fold_string(q)
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(folded)}%"
        cols = column_refs.map do |c|
          "#{sqlite_fold_sql_expression(c)} LIKE :#{bind}"
        end.join(" OR ")
        [cols, { bind => pattern }]
      end
    end

    def where_terms_match_sql_and_binds(connection, raw_query, column_refs, bind_prefix: "ua")
      terms = raw_query.to_s.strip.split(/\s+/).reject(&:blank?)
      return [nil, {}] if terms.empty?
      raise ArgumentError, "column_refs required" if column_refs.blank?

      binds = {}
      fragments = terms.each_with_index.map do |term, i|
        bind_key = :"#{bind_prefix}_#{i}"
        if postgresql_adapter?(connection)
          pattern = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
          binds[bind_key] = pattern
          column_refs.map do |c|
            "lower(unaccent(COALESCE(#{c}, ''))) ILIKE lower(unaccent(:#{bind_key}))"
          end.join(" OR ")
        else
          folded = sqlite_fold_string(term)
          pattern = "%#{ActiveRecord::Base.sanitize_sql_like(folded)}%"
          binds[bind_key] = pattern
          column_refs.map do |c|
            "#{sqlite_fold_sql_expression(c)} LIKE :#{bind_key}"
          end.join(" OR ")
        end
      end
      wrapped = fragments.map { |f| "(#{f})" }.join(" AND ")
      [wrapped, binds]
    end

    def sqlite_fold_string(term)
      s = term.to_s.downcase
      SQLITE_FOLD_PAIRS.each { |from, to| s = s.gsub(from, to) }
      s
    end

    def sqlite_fold_sql_expression(column_ref)
      from = SQLITE_FOLD_PAIRS.map(&:first).join
      to = SQLITE_FOLD_PAIRS.map(&:last).join
      safe_from = from.gsub("'", "''")
      safe_to = to.gsub("'", "''")
      "translate(lower(COALESCE(#{column_ref}, '')), '#{safe_from}', '#{safe_to}')"
    end
  end
end
