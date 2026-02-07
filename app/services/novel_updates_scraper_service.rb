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
    
    # Follow redirect to get actual URL
    actual_url = follow_redirect(chapter_url)
    
    @chapter_data << {
      group_name: group_name,
      chapter_title: chapter_title,
      chapter_url: actual_url
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

  def follow_redirect(redirect_url)
    begin
      # Make URL absolute if it starts with //
      if redirect_url.start_with?('//')
        redirect_url = "https:#{redirect_url}"
      elsif redirect_url.start_with?('/')
        redirect_url = "https://www.novelupdates.com#{redirect_url}"
      end
      
      # Create a new page/tab to follow the redirect
      new_page = @browser.create_page
      new_page.go_to(redirect_url)
      
      sleep(0.5)

      final_url = redirect_url

      loop do
        # Get the final URL after redirect
        final_url = new_page.current_url
        break if new_page.current_url != redirect_url && new_page.current_url != 'about:blank'
        sleep(0.5)
      end
      
      final_url
      
    rescue => e
      Rails.logger.error "Error following redirect for #{redirect_url}: #{e.message}"
      redirect_url
    ensure
      # Ensure page is closed even if there's an error
      if new_page
        begin
          new_page.close
        rescue => close_error
          # Ignore close errors since we're just cleaning up
        end
      end
    end
  end

  def process_scraped_data
    return unless @target_group && @chapter_data.any?

    Rails.logger.info "Processing scraped data for group: #{@target_group}"
    
    # Step 1: Find or create website based on group name
    website = find_or_create_website
    
    # Step 2: Extract novel name from URL and find or create novel
    novel = find_or_create_novel(website)
    
    # Step 3: Create chapters (skip duplicates)
    create_chapters(novel)
    
    Rails.logger.info "Data processing complete"
  end

  def find_or_create_website
    # Check if website with this group name already exists
    website = Website.find_by(name: @target_group)
    
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
    # Extract novel name from URL
    novel_name = extract_novel_name_from_url
    return nil unless novel_name
    
    # Clean novel link (remove everything after the novel name)
    clean_novel_link = clean_novel_url
    
    # Check if novel with this name already exists for this website
    novel = Novel.find_by(name: novel_name, website: website)
    
    if novel
      Rails.logger.info "Found existing novel: #{novel.name}"
      return novel
    end
    
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

  def create_chapters(novel)
    return unless novel
    
    created_count = 0
    skipped_count = 0
    
    @chapter_data.each do |chapter_data|
      # Check if chapter already exists
      existing_chapter = Chapter.find_by(
        name: chapter_data[:chapter_title],
        novel: novel
      )
      
      if existing_chapter
        skipped_count += 1
        next
      end
      
      # Create new chapter
      Chapter.create!(
        name: chapter_data[:chapter_title],
        link: chapter_data[:chapter_url],
        novel: novel
      )
      
      created_count += 1
    end
    
    Rails.logger.info "Created #{created_count} new chapters, skipped #{skipped_count} existing chapters"
  end

  def cleanup_browser
    @browser&.quit
  end
end