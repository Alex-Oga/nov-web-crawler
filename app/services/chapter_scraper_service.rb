require 'nokogiri'
require 'open-uri'
require 'ferrum'

class ChapterScraperService
  # Minimum word count threshold to consider content sufficient
  MIN_WORD_COUNT = 100
  
  def initialize(chapter)
    @chapter = chapter
  end

  def scrape_content

    return parse_existing_content if @chapter.content.present?
    return ["No link provided"] unless @chapter.link.present?

    setup_browser

    content = try_simple_fetch(@chapter)
    if content.empty? || content.include?("No content found")
      content = try_browser_fetch(@chapter)
    end

    if content.any? && !content.include?("No content found")
      @chapter.update!(content: content.join("\n\n"))
      content
    else
      ["No content found"]
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

  def try_simple_fetch(chapter)
    begin
      # Try fast browser fetch first (headless DOM) — cheaper than full extraction path
      @browser.go_to(chapter.link)
      wait_for_content_load
      page_source = @browser.body
      doc = Nokogiri::HTML(page_source)
      content = extract_main_content(doc)

      # If content is too small, try the more thorough browser extraction path
      if total_words(content) < MIN_WORD_COUNT
        Rails.logger.debug "Simple fetch produced #{total_words(content)} words (<#{MIN_WORD_COUNT}), falling back to try_browser_fetch for #{chapter.name}"
        alt = try_browser_fetch(chapter)
        return alt if alt.present? && !alt.include?("No content found")
      end

      return content
    rescue => e
      Rails.logger.debug "Try_simple_fetch (browser step) failed for #{chapter.name}: #{e.message}"
    end

    begin
      # Fallback to a simple open-uri fetch
      doc = Nokogiri::HTML(URI.open(chapter.link))
      content = extract_main_content(doc)

      if total_words(content) < MIN_WORD_COUNT && @browser
        Rails.logger.debug "Open-uri fetch produced #{total_words(content)} words (<#{MIN_WORD_COUNT}), falling back to try_browser_fetch for #{chapter.name}"
        alt = try_browser_fetch(chapter)
        return alt if alt.present? && !alt.include?("No content found")
      end

      content
    rescue => e
      Rails.logger.debug "Simple fetch failed for #{chapter.name}: #{e.message}"
      []
    end
  end

  def try_browser_fetch(chapter)
    return [] unless @browser

    @browser.go_to(chapter.link)
    wait_for_content_load
    
    page_source = @browser.body
    doc = Nokogiri::HTML(page_source)
    
    # Use the same extraction logic as ChapterScraperService
    content = extract_main_content(doc)
    
    if content.empty? || content.include?("No content found")
      content = try_alternative_extraction(doc)
    end
    
    content
  rescue => e
    Rails.logger.error "Browser fetch failed for #{chapter.name}: #{e.message}"
    []
  end

  def wait_for_content_load
    max_attempts = 10
    attempt = 0
    
    while attempt < max_attempts
      current_html = @browser.body
      break if content_likely_loaded?(current_html)
      
      attempt += 1
      sleep(0.5)
    end
  end

  def content_likely_loaded?(html)
    doc = Nokogiri::HTML(html)
    paragraphs = doc.css('p').select { |p| p.text.strip.length > 50 }
    paragraphs.length > 3
  end

  def total_words(content_array)
    return 0 unless content_array.is_a?(Array)
    content_array.join(' ').split.size
  end

  # Copy the extraction methods from ChapterScraperService
  def extract_main_content(doc)
    content_by_class = {}
    
    doc.css('p').each do |p|
      text = p.text.strip
      next if text.empty? || text.length < 20
      
      parent_path = build_parent_path(p)
      content_by_class[parent_path] ||= []
      content_by_class[parent_path] << text
    end

    largest_class = content_by_class.max_by { |class_name, paragraphs| 
      paragraphs.join(' ').length 
    }

    if largest_class && largest_class[1].length > 2
      largest_class[1]
    else
      ["No content found"]
    end
  end

  def try_alternative_extraction(doc)
    # Copy from ChapterScraperService
    content_selectors = [
      '.chapter-content', '.story-content', '.post-content', 
      '.entry-content', '.main-content', '.chapter-text',
      '#content', '#chapter', '.chapter', '.story',
      '.text-content', '.novel-content', '.reading-content'
    ]
    
    content_selectors.each do |selector|
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
    
    ["No content found with alternative methods"]
  end

  def build_parent_path(element)
    path_parts = element.ancestors.map { |a| a['class'] }.compact
    path_parts << element.parent['class'] if element.parent && element.parent['class']
    
    if path_parts.any?
      path_parts.join(' > ')
    else
      'no-class'
    end
  end

  def cleanup_browser
    @browser&.quit
    Rails.logger.info "Browser closed for batch scraping"
  end

end