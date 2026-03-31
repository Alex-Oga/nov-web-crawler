# frozen_string_literal: true

require 'nokogiri'
require 'open-uri'
require 'ferrum'

class BatchChapterScraperService
  include ContentExtraction
  include RedirectResolver

  def initialize(chapters = nil)
    @chapters = chapters || Chapter.where(content: [nil, ''])
    @browser = nil
    @stats = { scraped: 0, failed: 0, total: 0 }
  end

  def scrape_all_content
    @stats[:total] = @chapters.count
    return { chapters: [], stats: @stats } if @chapters.empty?

    Rails.logger.info "Starting batch scrape for #{@stats[:total]} chapters"

    begin
      setup_browser

      @chapters.find_each(batch_size: scraper_config[:batch_size] || 10) do |chapter|
        scrape_single_chapter(chapter)
        apply_rate_limit
      end
    rescue => e
      Rails.logger.error "Batch scraper error: #{e.message}"
    ensure
      cleanup_browser
    end

    Rails.logger.info "Batch scrape completed: #{@stats}"
    { chapters: @chapters.reload, stats: @stats }
  end

  attr_reader :stats

  private

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
    Rails.logger.info "Browser initialized for batch scraping"
  end

  def scrape_single_chapter(chapter)
    Rails.logger.info "Scraping chapter: #{chapter.name}"

    unless chapter.link.present?
      Rails.logger.warn "No link for chapter: #{chapter.name}"
      @stats[:failed] += 1
      return
    end

    begin
      content = try_browser_fetch(chapter)

      if !content_sufficient?(content)
        content = try_simple_fetch(chapter)
      end

      if content.any? && !content.include?('No content found')
        chapter.update!(content: content.join("\n\n"))
        @stats[:scraped] += 1
        Rails.logger.info "Successfully scraped: #{chapter.name} (#{total_words(content)} words)"
      else
        @stats[:failed] += 1
        Rails.logger.warn "Failed to scrape: #{chapter.name}"
      end
    rescue => e
      @stats[:failed] += 1
      Rails.logger.error "Error scraping #{chapter.name}: #{e.message}"
    end
  end

  def try_browser_fetch(chapter)
    return [] unless @browser

    url = chapter.link
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
    extract_main_content(doc)
  rescue => e
    Rails.logger.debug "Simple fetch failed for #{chapter.name}: #{e.message}"
    []
  end

  def cleanup_browser
    @browser&.quit
    Rails.logger.info "Browser closed for batch scraping"
  end
end