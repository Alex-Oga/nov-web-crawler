# frozen_string_literal: true

require 'nokogiri'
require 'open-uri'
require 'ferrum'

class ChapterScraperService
  include ContentExtraction
  include RedirectResolver

  def initialize(chapter)
    @chapter = chapter
  end

  def scrape_content
    return parse_existing_content if @chapter.content.present?
    return ['No link provided'] unless @chapter.link.present?

    setup_browser
    content = fetch_chapter_content(@chapter)

    if content.any? && !content.include?('No content found')
      @chapter.update!(content: content.join("\n\n"))
      content
    else
      ['No content found']
    end
  ensure
    cleanup_browser
  end

  private

  def parse_existing_content
    @chapter.content.split("\n\n")
  end

  def setup_browser
    @browser = Ferrum::Browser.new(
      headless: false,
      timeout: 30,
      browser_options: {
        'no-sandbox': nil,
        'disable-web-security': nil,
        'disable-images': nil,
        'disable-extensions': nil
      }
    )
    Rails.logger.info "Browser initialized for content scraping"
  end

  def fetch_chapter_content(chapter)
    # Try browser fetch first (handles JS-rendered content)
    content = try_browser_fetch(chapter)

    # Fallback to simple open-uri fetch if browser fetch fails
    if !content_sufficient?(content)
      Rails.logger.debug "Browser fetch insufficient for #{chapter.name}, trying open-uri"
      content = try_simple_fetch(chapter)
    end

    content
  end

  def try_browser_fetch(chapter)
    return [] unless @browser

    url = chapter.link
    Rails.logger.info "Fetching chapter from: #{url}"

    # Handle Cloudflare if detected
    @browser.go_to(url)

    if cloudflare_challenge_detected?(@browser.body)
      handle_cloudflare_challenge(@browser)
    end

    wait_for_content_load(@browser)

    doc = Nokogiri::HTML(@browser.body)
    content = extract_main_content(doc)

    if content.empty? || content.include?('No content found')
      content = try_alternative_extraction(doc)
    end

    content
  rescue => e
    Rails.logger.error "Browser fetch failed for #{chapter.name}: #{e.message}"
    []
  end

  def try_simple_fetch(chapter)
    doc = Nokogiri::HTML(URI.open(chapter.link))
    content = extract_main_content(doc)

    if !content_sufficient?(content)
      content = try_alternative_extraction(doc)
    end

    content
  rescue => e
    Rails.logger.debug "Simple fetch failed for #{chapter.name}: #{e.message}"
    []
  end

  def cleanup_browser
    @browser&.quit
    Rails.logger.info "Browser closed for content scraping"
  end
end