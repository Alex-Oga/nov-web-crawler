# frozen_string_literal: true

# Shared content extraction methods for chapter scraping services.
# Provides DOM parsing, content detection, and text extraction utilities.
module ContentExtraction
  extend ActiveSupport::Concern

  # Minimum word count to consider content valid
  MIN_WORD_COUNT = 100

  # Common CSS selectors for chapter content containers
  CONTENT_SELECTORS = [
    ".chapter-content", ".story-content", ".post-content",
    ".entry-content", ".main-content", ".chapter-text",
    "#content", "#chapter", ".chapter", ".story",
    ".text-content", ".novel-content", ".reading-content",
    ".reader-content", ".txt", ".content-area"
  ].freeze

  # Extract main content from a parsed document by grouping paragraphs
  # by their parent CSS class hierarchy and returning the largest group.
  def extract_main_content(doc)
    content_by_class = {}

    doc.css("p").each do |p|
      text = p.text.strip
      next if text.empty? || text.length < 20

      parent_path = build_parent_path(p)
      content_by_class[parent_path] ||= []
      content_by_class[parent_path] << text
    end

    largest_class = content_by_class.max_by do |_class_name, paragraphs|
      paragraphs.join(" ").length
    end

    if largest_class && largest_class[1].length > 2
      largest_class[1]
    else
      [ "No content found" ]
    end
  end

  # Try alternative extraction using common content container selectors
  def try_alternative_extraction(doc)
    CONTENT_SELECTORS.each do |selector|
      elements = doc.css(selector)
      next if elements.empty?

      text_blocks = []
      elements.each do |element|
        text = element.text.strip
        next if text.empty?

        paragraphs = text.split(/\n\s*\n/).map(&:strip).reject(&:empty?)
        paragraphs = paragraphs.select { |p| p.length > 20 }

        text_blocks.concat(paragraphs) if paragraphs.any?
      end

      return text_blocks if text_blocks.any?
    end

    [ "No content found with alternative methods" ]
  end

  # Build CSS class path from element ancestors for content grouping
  def build_parent_path(element)
    path_parts = element.ancestors.map { |a| a["class"] }.compact
    path_parts << element.parent["class"] if element.parent&.[]("class")

    path_parts.any? ? path_parts.join(" > ") : "no-class"
  end

  # Wait for dynamic content to load by polling for paragraph elements
  def wait_for_content_load(browser, max_attempts: 10, interval: 0.5)
    attempt = 0

    while attempt < max_attempts
      current_html = browser.body
      break if content_likely_loaded?(current_html)

      attempt += 1
      sleep(interval)
    end
  end

  # Check if page likely has loaded content (3+ paragraphs with >50 chars)
  def content_likely_loaded?(html)
    doc = Nokogiri::HTML(html)
    paragraphs = doc.css("p").select { |p| p.text.strip.length > 50 }
    paragraphs.length > 3
  end

  # Count total words in content array
  def total_words(content_array)
    return 0 unless content_array.is_a?(Array)
    content_array.join(" ").split.size
  end

  # Check if extracted content meets minimum word threshold
  def content_sufficient?(content_array)
    total_words(content_array) >= MIN_WORD_COUNT
  end
end
