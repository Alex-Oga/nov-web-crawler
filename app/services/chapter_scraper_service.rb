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

    begin
      # Try simple HTTP fetch first (faster for non-JS sites)
      content = try_simple_fetch
      word_count = count_words(content)
      
      # Check if we got sufficient content
      if content.any? && !content.include?("No content found") && word_count >= MIN_WORD_COUNT
        Rails.logger.info "Simple fetch successful with #{word_count} words"
        @chapter.update(content: content.join("\n\n"))
        return content
      end
      
      # Fall back to browser automation for JS sites if content is insufficient
      Rails.logger.info "Simple fetch returned insufficient content (#{word_count} words < #{MIN_WORD_COUNT}), trying browser automation for: #{@chapter.link}"
      content = try_browser_fetch
      
      if content.any? && !content.include?("No content found")
        @chapter.update(content: content.join("\n\n"))
        content
      else
        ["No content found"]
      end
    rescue => e
      Rails.logger.error "Failed to fetch content from #{@chapter.link}: #{e.message}"
      ["Content temporarily unavailable"]
    end
  end

  private

  def parse_existing_content
    @chapter.content.split("\n\n")
  end

  def count_words(content_array)
    return 0 if content_array.empty?
    
    total_words = content_array.sum do |paragraph|
      paragraph.split(/\s+/).length
    end
    
    total_words
  end

  def try_simple_fetch
    begin
      doc = Nokogiri::HTML(URI.open(@chapter.link))
      extract_main_content(doc)
    rescue Socket::ResolutionError, Net::TimeoutError => e
      Rails.logger.warn "Simple fetch failed: #{e.message}"
      []
    end
  end

  def try_browser_fetch
    browser = nil
    
    begin
      # Setup headless browser
      browser = Ferrum::Browser.new(
        headless: true,  # Run in background
        timeout: 30,
        browser_options: {
          'no-sandbox': nil,
          'disable-web-security': nil,
          'disable-images': nil,  # Speed up loading
          'disable-extensions': nil
        }
      )
      
      Rails.logger.info "Navigating to: #{@chapter.link}"
      browser.go_to(@chapter.link)
      
      # Wait for potential content to load
      wait_for_content_load(browser)
      
      # Get the fully rendered page
      page_source = browser.body
      doc = Nokogiri::HTML(page_source)
      
      # Try multiple content extraction strategies
      content = extract_main_content(doc)
      
      # If still no content, try alternative selectors
      if content.empty? || content.include?("No content found")
        content = try_alternative_extraction(doc)
      end
      
      word_count = count_words(content)
      Rails.logger.info "Browser fetch completed with #{word_count} words"
      
      content
      
    rescue => e
      Rails.logger.error "Browser fetch failed: #{e.message}"
      ["Browser fetch failed: #{e.message}"]
    ensure
      browser&.quit
    end
  end

  def wait_for_content_load(browser)
    # Wait for common content indicators to appear
    max_attempts = 20
    attempt = 0
    
    while attempt < max_attempts
      begin
        # Check if content has loaded by looking for common patterns
        current_html = browser.body
        
        # Look for signs that content has loaded
        if content_likely_loaded?(current_html)
          Rails.logger.info "Content appears to be loaded after #{attempt + 1} attempts"
          return
        end
        
      rescue
        # Continue waiting if there's an error checking
      end
      
      attempt += 1
      sleep(0.5)  # Wait 500ms between checks
    end
    
    Rails.logger.info "Finished waiting for content load after #{max_attempts} attempts"
  end

  def content_likely_loaded?(html)
    # Check for signs that JavaScript content has loaded
    doc = Nokogiri::HTML(html)
    
    # Look for substantial paragraph content
    paragraphs = doc.css('p').select { |p| p.text.strip.length > 50 }
    return true if paragraphs.length > 3
    
    # Look for common content container patterns
    content_indicators = [
      '.chapter-content', '.story-content', '.post-content', 
      '.entry-content', '.main-content', '.chapter-text',
      '#content', '#chapter', '.chapter', '.story'
    ]
    
    content_indicators.any? do |selector|
      elements = doc.css(selector)
      elements.any? { |el| el.text.strip.length > 100 }
    end
  end

  def extract_main_content(doc)
    # Get all paragraphs and group by parent class
    content_by_class = {}
    
    doc.css('p').each do |p|
      # Skip very short paragraphs (likely navigation/ui elements)
      text = p.text.strip
      next if text.empty? || text.length < 20
      
      # Create a unique key based on the full path to avoid mixing content
      parent_path = build_parent_path(p)
      
      content_by_class[parent_path] ||= []
      content_by_class[parent_path] << text
    end

    # Find the class with the largest total content
    largest_class = content_by_class.max_by { |class_name, paragraphs| 
      paragraphs.join(' ').length 
    }

    if largest_class && largest_class[1].length > 2
      Rails.logger.info "Selected class '#{largest_class[0]}' with #{largest_class[1].length} paragraphs"
      largest_class[1] # Return the paragraphs array
    else
      ["No content found"]
    end
  end

  def try_alternative_extraction(doc)
    # Try different content extraction strategies for stubborn sites
    
    # Strategy 1: Look for common content container selectors
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
        # Extract all text, splitting by double newlines or paragraph breaks
        text = element.text.strip
        next if text.empty?
        
        # Split into paragraphs and clean
        paragraphs = text.split(/\n\s*\n/).map(&:strip).reject(&:empty?)
        paragraphs = paragraphs.select { |p| p.length > 20 }  # Filter short paragraphs
        
        text_blocks.concat(paragraphs) if paragraphs.any?
      end
      
      if text_blocks.any?
        Rails.logger.info "Alternative extraction found content with selector: #{selector}"
        return text_blocks
      end
    end
    
    # Strategy 2: Look for the largest text block anywhere
    all_elements = doc.css('div, section, article, main')
    largest_element = all_elements.max_by { |el| el.text.length }
    
    if largest_element && largest_element.text.length > 500
      text = largest_element.text.strip
      paragraphs = text.split(/\n\s*\n/).map(&:strip).reject(&:empty?)
      paragraphs = paragraphs.select { |p| p.length > 20 }
      
      if paragraphs.length > 2
        Rails.logger.info "Alternative extraction found content in largest element"
        return paragraphs
      end
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
end