# frozen_string_literal: true

# Background job for batch scraping chapter content.
# Processes all chapters without content for a given novel.
class ScrapeChaptersJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff on failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # @param novel_id [Integer] The novel ID to scrape chapters for
  # @param chapter_ids [Array<Integer>] Optional specific chapter IDs to scrape
  def perform(novel_id, chapter_ids: nil)
    novel = Novel.find_by(id: novel_id)

    unless novel
      Rails.logger.error "ScrapeChaptersJob: Novel #{novel_id} not found"
      return
    end

    chapters = if chapter_ids.present?
      novel.chapters.where(id: chapter_ids, content: [ nil, "" ])
    else
      novel.chapters.where(content: [ nil, "" ])
    end

    if chapters.empty?
      Rails.logger.info "ScrapeChaptersJob: No chapters to scrape for novel #{novel_id}"
      return
    end

    Rails.logger.info "ScrapeChaptersJob: Starting batch scrape for #{chapters.count} chapters (novel #{novel_id})"

    scraper = BatchChapterScraperService.new(chapters)
    result = scraper.scrape_all_content

    Rails.logger.info "ScrapeChaptersJob: Completed - #{result[:stats]}"
  end
end
