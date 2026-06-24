# frozen_string_literal: true

# Določi LinkCategory za URL glede na domeno/ključne besede (prva ujemajoča pravila zmaga).
class LinkCategorizer
  IMPORTED_LINKS_CATEGORY = "Uvožene povezave"
  FALLBACK_CATEGORY = "Ostale povezave"

  # Zaporedje je pomembno — specifičnejši vzorci pred splošnejšimi (npr. COBISS pred izum.si).
  CATEGORY_RULES = [
    {
      name: "COBISS",
      position: 12,
      patterns: %w[cobiss.si cobiss7.izum cobiss.izum]
    },
    {
      name: "Strokovni viri",
      position: 13,
      patterns: %w[
        povezave.php
        sssg.nuk
        nuk.uni-lj.si
        udcmrf
        islovar
        nektar
        dfmk
        nuk.si
        izum.si
        top_gradivo
        biblioblog
        knjiznicarskenovice
        revija-knjiznica
        zbds
        ebsco
      ]
    },
    {
      name: "Interni sistemi",
      position: 11,
      patterns: %w[
        kl-kl.si
        knjiznica-lendava.si
        digitalna.knjiznica
        owa.kl-kl
        webmail.knjiznica
        tabla.knjiznica
        galerija.knjiznica
        /admin/
        194.249.80
      ]
    },
    {
      name: "Digitalne knjižnice",
      position: 14,
      patterns: %w[dlib.si nagykar.hu theeuropeanlibrary europeana]
    },
    {
      name: "Pravni in splošni viri",
      position: 15,
      patterns: %w[
        uradni-list
        iusinfo
        tax-fin-lex
        stat.si
        itis.si
        odpiralnicasi
        podjetnik
        zps.si
      ]
    },
    {
      name: "Občine in lokalno",
      position: 16,
      patterns: %w[
        lendava.si
        dobrovnik
        crensovci
        turnisce
        kobilje
        velika-polana
        odranci
        lendava.net
        zkp-lendava
        mnmi-zkmn
        nepujsag
        gml.si
      ]
    }
  ].freeze

  def self.category_name_for(url)
    new(url).category_name
  end

  def self.ensure_category!(name)
    rule = CATEGORY_RULES.find { |r| r[:name] == name }
    position = rule&.fetch(:position) || 99

    LinkCategory.find_or_create_by!(name: name) do |category|
      category.position = position
    end
  end

  def initialize(url)
    @url = url.to_s.strip.downcase
  end

  def category_name
    CATEGORY_RULES.each do |rule|
      return rule[:name] if rule[:patterns].any? { |pattern| @url.include?(pattern) }
    end

    FALLBACK_CATEGORY
  end
end
