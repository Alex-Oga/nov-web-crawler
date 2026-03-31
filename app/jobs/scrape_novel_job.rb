# frozen_string_literal: true

# Background job for scraping a novel from NovelUpdates.
# Discovers chapters and optionally queues content scraping.
class ScrapeNovelJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff on failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # @param novelupdates_url [String] The NovelUpdates series URL
  # @param scrape_content [Boolean] Whether to queue content scraping after discovery
  def perform(novelupdates_url, scrape_content: false)
    Rails.logger.info "ScrapeNovelJob: Starting for #{novelupdates_url}"

    scraper = NovelUpdatesScraperService.new(novelupdates_url)
    chapter_data = scraper.scrape_chapters

    if chapter_data.empty?
      Rails.logger.warn "ScrapeNovelJob: No chapters found for #{novelupdates_url}"
      return
    end

    Rails.logger.info "ScrapeNovelJob: Discovered #{chapter_data.length} chapters"

    # Optionally queue content scraping for the novel
    if scrape_content
      novel = find_novel_from_url(novelupdates_url)
      if novel
        ScrapeChaptersJob.perform_later(novel.id)
        Rails.logger.info "ScrapeNovelJob: Queued content scraping for novel #{novel.id}"
      end
    end
  end

  private

  def find_novel_from_url(url)
    match = url.match(%r{(https://www\.novelupdates\.com/series/[^/?]+)})
    return nil unless match

    clean_link = "#{match[1]}/"
    Novel.find_by(link: clean_link)
  end
end
