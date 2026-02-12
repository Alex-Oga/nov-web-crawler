require 'nokogiri'
require 'ferrum'
require 'uri'

class NovelUpdatesScraperService
  def initialize(scrape_url)
    @scrape_url = scrape_url
    @chapter_data = []
    @browser = nil
    @target_group = nil
    @group_link = nil
  end

  def scrape_chapters
    return [] unless @scrape_url.present?

    # Validate URL format
    unless valid_novelupdates_url?
      Rails.logger.error "Invalid NovelUpdates URL: #{@scrape_url}"
      return []
    end

    begin
      setup_browser
      login_to_site
      navigate_and_scrape
      
      # Process and save the scraped data
      if @chapter_data.any?
        process_scraped_data
      end
      
      @chapter_data
    rescue => e
      Rails.logger.error "Browser automation error: #{e.message}"
      []
    ensure
      cleanup_browser
    end
  end

  private

  def valid_novelupdates_url?
    return false unless @scrape_url.is_a?(String)
    
    # Check if URL starts with the required prefix
    return false unless @scrape_url.start_with?('https://www.novelupdates.com/series/')
    
    # Optional: Additional validation
    begin
      uri = URI.parse(@scrape_url)
      
      # Ensure it's a valid URI
      return false unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      
      # Ensure correct host
      return false unless uri.host == 'www.novelupdates.com'
      
      # Ensure path starts correctly
      return false unless uri.path.start_with?('/series/')
      
      Rails.logger.info "Valid NovelUpdates URL: #{@scrape_url}"
      true
      
    rescue URI::InvalidURIError => e
      Rails.logger.error "Invalid URI format: #{e.message}"
      false
    end
  end

  def setup_browser
    @browser = Ferrum::Browser.new(headless: false)
  end

  def login_to_site
    # Set page timeout
    @browser.timeout = 30

    @browser.go_to("https://www.novelupdates.com/login/")
    
    # Wait for page to load and fill in login credentials
    @browser.at_css('input[name="log"]').focus.type(ENV['SCRAPE_USERNAME'])
    @browser.at_css('input[name="pwd"]').focus.type(ENV['SCRAPE_PASSWORD'])

    # Click login button
    @browser.at_css('input[type="submit"]').click
    
    # Wait for login to complete
    sleep(2)
  end

  def navigate_and_scrape
    @browser.go_to(@scrape_url)
    sleep(1)
    
    # Extract chapters from all pages
    loop do
      scrape_current_page
      break unless navigate_to_next_page
    end
    
    Rails.logger.info "Extracted #{@chapter_data.length} chapters"
  end

  def scrape_current_page
    # Get page source and parse with Nokogiri
    page_source = @browser.body
    doc = Nokogiri::HTML(page_source)
    
    # Extract chapter data from the table using Nokogiri
    rows = doc.css('#myTable tbody tr')
    
    if rows.empty?
      Rails.logger.warn "No table rows found"
      return
    end
    
    rows.each do |row|
      extract_chapter_from_row(row)
    end
  end

  def extract_chapter_from_row(row)
    cells = row.css('td')
    
    return unless cells.length >= 3

    # Extract group name and URL from second cell
    group_link = cells[1].at_css('a')
    group_name = group_link&.text&.strip || 'Unknown'
    group_url = group_link&.[]('href')

    # Set target group from the first chapter found
    if @target_group.nil?
      @target_group = group_name
      @group_link = group_url
      Rails.logger.info "Target group set to: #{@target_group}"
    end

    # Skip chapters not from the target group
    return unless group_name == @target_group
    
    # Extract chapter title and URL from third cell
    chapter_link = cells[2].at_css('a')
    
    return unless chapter_link

    chapter_title = chapter_link.text.strip
    chapter_url = chapter_link['href']

    # Make URL absolute if it starts with //
    if chapter_url.start_with?('//')
      chapter_url = "https:#{chapter_url}"
    elsif chapter_url.start_with?('/')
      chapter_url = "https://www.novelupdates.com#{chapter_url}"
    end
    
    @chapter_data << {
      group_name: group_name,
      chapter_title: chapter_title,
      chapter_url: chapter_url
    }
  end

  def navigate_to_next_page
    doc = Nokogiri::HTML(@browser.body)
    next_page_link = doc.at_css('a.next_page')
    
    return false unless next_page_link&.[]('href')

    next_url = build_absolute_url(next_page_link['href'])
    
    # Navigate to next page
    @browser.go_to(next_url)
    sleep(1)
    true
  end

  def build_absolute_url(url)
    if url.start_with?('./')
      URI.join(@scrape_url, url).to_s
    elsif !url.start_with?('http')
      "https://www.novelupdates.com#{url}"
    else
      url
    end
  end

  def process_scraped_data
    return unless @target_group && @chapter_data.any?

    Rails.logger.info "Processing scraped data for group: #{@target_group}"
    
    # Step 1: Find or create website based on group name
    website = find_or_create_website
    
    # Step 2: Extract novel name from URL and find or create novel
    novel = find_or_create_novel(website)
    
    # Step 3: Create or sync chapters (ensure proper positions)
    sync_positions_from_source(novel, @chapter_data) if novel
    
    Rails.logger.info "Data processing complete"
  end

  def find_or_create_website
    # Check if website with this group link already exists
    website = Website.find_by(link: @group_link)
    
    if website
      Rails.logger.info "Found existing website: #{website.name}"
      return website
    end
    
    # Create new website
    website = Website.create!(
      name: @target_group,
      link: @group_link
    )
    
    Rails.logger.info "Created new website: #{website.name}"
    website
  end

  def find_or_create_novel(website)
    # Extract clean novel link from URL
    clean_novel_link = clean_novel_url
    return nil unless clean_novel_link
    
    # Check if novel with this name already exists for this website
    novel = Novel.find_by(link: clean_novel_link, website: website)
    
    if novel
      Rails.logger.info "Found existing novel: #{novel.name}"
      return novel
    end

    # Extract novel name for new novel creation
    novel_name = extract_novel_name_from_url
    return nil unless novel_name
    
    # Create new novel
    novel = Novel.create!(
      name: novel_name,
      link: clean_novel_link,
      website: website
    )
    
    Rails.logger.info "Created new novel: #{novel.name}"
    novel
  end

  def extract_novel_name_from_url
    # Extract novel name from URL like: https://www.novelupdates.com/series/NovelName/
    match = @scrape_url.match(%r{/series/([^/?]+)})
    if match
      novel_name = match[1].gsub('-', ' ').titleize
      Rails.logger.info "Extracted novel name: #{novel_name}"
      return novel_name
    end
    
    Rails.logger.error "Could not extract novel name from URL: #{@scrape_url}"
    nil
  end

  def clean_novel_url
    # Clean URL to remove everything after /NovelName/
    match = @scrape_url.match(%r{(https://www\.novelupdates\.com/series/[^/?]+)})
    if match
      clean_url = "#{match[1]}/"
      Rails.logger.info "Cleaned novel URL: #{clean_url}"
      return clean_url
    end
    
    Rails.logger.warn "Could not clean novel URL, using original: #{@scrape_url}"
    @scrape_url
  end

  # New: sync positions from the source list (handles inserted chapters)
  def sync_positions_from_source(novel, source_chapter_list)
    return unless novel && source_chapter_list.present?

    # Make a working copy
    source_list = source_chapter_list.map do |cd|
      {
        title: cd[:chapter_title].to_s.strip,
        link: cd[:chapter_url].to_s.strip
      }
    end

    # If scraped newest-first, reverse to be oldest->newest
    source_list.reverse! if looks_newest_first?(source_list)

    ActiveRecord::Base.transaction do
      source_list.each_with_index do |cd, idx|
        pos = idx + 1
        title = cd[:title]
        link = cd[:link]

        chapter = nil
        # Prefer matching by link (most reliable), then by name
        chapter = Chapter.find_by(link: link, novel: novel) if link.present?
        chapter ||= Chapter.find_by(name: title, novel: novel)

        if chapter
          # Update name/link if they changed
          updates = {}
          updates[:name] = title if chapter.name != title
          updates[:link] = link if link.present? && chapter.link != link
          chapter.update_columns(updates) if updates.any?

          # Update position if different or nil
          if chapter.position != pos
            chapter.update_columns(position: pos)
          end
        else
          # Create missing chapter with correct position
          Chapter.create!(
            name: title,
            link: link,
            novel: novel,
            position: pos
          )
        end
      end

      # After syncing, ensure any remaining chapters (not present in source_list)
      # that have nil positions get assigned a sequential position after the last one.
      max_pos = novel.chapters.maximum(:position) || source_list.length
      novel.chapters.where(position: nil).find_each do |ch|
        max_pos += 1
        ch.update_columns(position: max_pos)
      end
    end
  rescue => e
    Rails.logger.error "sync_positions_from_source failed for novel #{novel&.id}: #{e.message}"
  end

  # Heuristics to determine whether scraped list is newest-first
  def looks_newest_first?(list)
    return false unless list.is_a?(Array) && list.size >= 2

    first_num = extract_chapter_number(list.first[:title])
    last_num  = extract_chapter_number(list.last[:title])

    return false unless first_num && last_num
    first_num > last_num
  end

  # Try to pull a numeric chapter index from the title (e.g. "Chapter 123", "Ch. 12.5")
  def extract_chapter_number(title)
    return nil unless title
    m = title.match(/chapter\s*([0-9]+(\.[0-9]+)?)/i) || title.match(/ch(?:\.)?\s*([0-9]+(\.[0-9]+)?)/i)
    m && m[1].to_f
  end

  def create_chapters(novel)
    # Keep compatibility: if we have raw @chapter_data, sync positions from that list
    sync_positions_from_source(novel, @chapter_data) if novel && @chapter_data.any?
  end

  def cleanup_browser
    @browser&.quit
  end
end