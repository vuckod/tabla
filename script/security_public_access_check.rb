#!/usr/bin/env ruby
# frozen_string_literal: true

# Varnostni pregled javnega dostopa (naloga 29, korak 7).
# Zagon: docker compose run --rm rails_app ruby script/security_public_access_check.rb

require_relative "../config/environment"

class PublicAccessSecurityCheck
  PASS = "✓"
  FAIL = "✗"

  def self.run!
    new.run!
  end

  CHROME_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
              "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

  def initialize
    @session = ActionDispatch::Integration::Session.new(Rails.application)
    configure_session!
    @failures = []
    @public_doc = Document.published.where(internal_only: false).first
    @internal_doc = Document.published.where(internal_only: true).first
    @reader = User.joins(:roles).find_by(roles: { name: "intranet_bralec" }) ||
              User.all.detect(&:bralec?)
    @editor = User.joins(:roles).find_by(roles: { name: "intranet_urednik" }) ||
              User.all.detect { |u| u.admin? || u.urednik? }
  end

  def run!
    puts "=== Varnostni pregled javnega dostopa ===\n"

    check_public_pages
    check_document_access
    check_admin_access
    check_visible_to_scopes
    check_search_filters

    puts "\n=== Povzetek ==="
    if @failures.empty?
      puts "#{PASS} Vsi pregledi uspešni (#{@checks} preverjanj)"
    else
      puts "#{FAIL} #{@failures.size} napak:"
      @failures.each { |f| puts "  - #{f}" }
      exit 1
    end
  end

  private

  def check_public_pages
    section "Javne strani (brez prijave)"
    assert_public_get("/", "domača stran")
    assert_public_get("/persons", "imenik")
    assert_public_get("/links", "povezave")
    assert_public_get("/documents", "seznam dokumentov")
    assert_public_get("/search", "iskanje (prazno)")
    assert_public_get("/search?q=test", "iskanje z nizom")
  end

  def check_document_access
    section "Zaščita dokumentov (brez prijave)"
    return skip_missing_doc! unless @public_doc

    assert_redirect_to_login("/documents/#{@public_doc.id}", "show")
    assert_redirect_to_login("/documents/#{@public_doc.id}/preview", "preview")
    assert_redirect_to_login("/documents/#{@public_doc.id}/download", "download")

    if @internal_doc
      assert_redirect_to_login("/documents/#{@internal_doc.id}", "internal show")
      assert_not_in_public_list(@internal_doc, "internal_only ni v javnem seznamu")
    else
      record_skip("ni internal_only dokumenta v bazi — delno preverjeno")
    end
  end

  def check_admin_access
    section "Admin zaščita (brez prijave)"
    assert_redirect_to_login("/admin/persons", "admin persons")
    assert_redirect_to_login("/admin/documents", "admin documents")
  end

  def check_visible_to_scopes
    section "visible_to(nil) obseg"
    public_count = Document.visible_to(nil).published.count
    all_published = Document.published.count
    internal_count = Document.published.where(internal_only: true).count

    if internal_count.positive?
      assert(public_count == all_published - internal_count,
             "visible_to(nil) izključi internal_only (#{public_count} != #{all_published - internal_count})")
    else
      record_skip("ni internal_only dokumentov — visible_to preverjen delno")
    end
  end

  def check_search_filters
    section "Iskanje — varnostni filter"
    controller = SearchController.new
    controller.request = ActionDispatch::TestRequest.create
    filter = controller.send(:build_meilisearch_security_filters)
    assert(filter.include?("internal_only = false"), "Meilisearch filter vključuje internal_only = false")
    assert(filter.include?("published = true"), "Meilisearch filter vključuje published = true")
  end

  def assert_public_get(path, label)
    @session.get(path)
  assert @session.response.successful? || @session.response.redirect?, "#{label} dostopen (#{@session.response.status})"
  end

  def assert_redirect_to_login(path, label)
    @session.get(path)
    assert @session.response.redirect? && @session.response.location.include?("/login"),
           "#{label} preusmeri na login (status=#{@session.response.status}, location=#{@session.response.location})"
    assert @session.request.session[:return_to] == path,
           "#{label} shrani return_to=#{path.inspect}"
    reset_session!
  end

  def configure_session!
    @session.host! "localhost"
    @session.headers "User-Agent", CHROME_UA
  end

  def reset_session!
    @session.reset!
    configure_session!
  end

  def assert_not_in_public_list(doc, label)
    @session.get("/documents")
    body = @session.response.body
    pattern = %r{/documents/#{doc.id}(?:["/?]|$)}
    assert !body.match?(pattern),
           "#{label} (link /documents/#{doc.id} ni v javnem seznamu)"
  end

  def assert(condition, message)
    @checks = (@checks || 0) + 1
    if condition
      puts "  #{PASS} #{message}"
    else
      puts "  #{FAIL} #{message}"
      @failures << message
    end
  end

  def record_skip(message)
    puts "  ~ #{message}"
  end

  def skip_missing_doc!
    record_skip("ni javnega dokumenta v bazi — preskočeno preverjanje show/preview/download")
  end

  def section(title)
    puts "\n#{title}"
  end
end

PublicAccessSecurityCheck.run!
