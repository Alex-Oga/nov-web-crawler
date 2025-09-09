require 'nokogiri'
require 'ferrum'
require 'uri'

class NovelUpdatesScraperService
  def initialize(scrape_url)
    @scrape_url = scrape_url
    @chapter_data = []
    @browser = nil
  end

  def scrape_chapters
    return [] unless @scrape_url.present?

    begin
      setup_browser
      login_to_site
      navigate_and_scrape
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

  def cleanup_browser
    @browser&.quit
  end
end