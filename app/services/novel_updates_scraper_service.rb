require 'nokogiri'
require 'ferrum'
require 'uri'
require 'open-uri'

class NovelUpdatesScraperService
  def initialize(scrape_url)
    @scrape_url = scrape_url
    @chapter_data = []
    @browser = nil
    @target_group = nil
    @group_link = nil

    # metadata placeholders used after scraping
    @novel_image_url = nil
    @novel_description = nil
    @novel_genres = []
  end

  def scrape_chapters
    return [] unless @scrape_url.present?

    unless valid_novelupdates_url?
      Rails.logger.error "Invalid NovelUpdates URL: #{@scrape_url}"
      return []
    end

    begin
      setup_browser
      login_to_site

      # Navigate and collect chapters across pages
      navigate_and_scrape

      # After all chapters are found, extract metadata from the series page
      extract_metadata_from_series_page

      # Process and persist scraped data (chapters + metadata)
      process_scraped_data

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
    return false unless @scrape_url.start_with?('https://www.novelupdates.com/series/')
    begin
      uri = URI.parse(@scrape_url)
      return false unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      return false unless uri.host == 'www.novelupdates.com'
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
    @browser.timeout = 30
  end

  def login_to_site
    # If credentials are present, try to log in — otherwise skip.
    return unless ENV['SCRAPE_USERNAME'].present? && ENV['SCRAPE_PASSWORD'].present?

    @browser.go_to("https://www.novelupdates.com/login/")
    sleep(0.5)

    begin
      @browser.at_css('input[name="log"]').focus.type(ENV['SCRAPE_USERNAME'])
      @browser.at_css('input[name="pwd"]').focus.type(ENV['SCRAPE_PASSWORD'])
      @browser.at_css('input[type="submit"]').click
      sleep(1)
    rescue => e
      Rails.logger.debug "NovelUpdates login failed or not necessary: #{e.message}"
    end
  end

  # Keep the original navigation/collection logic intact
  def navigate_and_scrape
    @browser.go_to(@scrape_url)
    sleep(1)

    loop do
      scrape_current_page
      break unless navigate_to_next_page
    end

    Rails.logger.info "Extracted #{@chapter_data.length} chapters"
  end

  def scrape_current_page
    page_source = @browser.body
    doc = Nokogiri::HTML(page_source)

    rows = doc.css('#myTable tbody tr')
    if rows.empty?
      Rails.logger.warn "No chapter rows found on current page"
      return
    end

    rows.each do |row|
      extract_chapter_from_row(row)
    end
  rescue => e
    Rails.logger.error "scrape_current_page failed: #{e.message}"
  end

  def extract_chapter_from_row(row)
    cells = row.css('td')
    return unless cells.length >= 3

    group_link = cells[1].at_css('a')
    group_name = group_link&.text&.strip || 'Unknown'
    group_url = group_link&.[]('href')

    if @target_group.nil?
      @target_group = group_name
      @group_link = group_url
      Rails.logger.info "Target group set to: #{@target_group}"
    end

    return unless group_name == @target_group

    chapter_link = cells[2].at_css('a')
    return unless chapter_link

    chapter_title = chapter_link.text.strip
    chapter_url = chapter_link['href']

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

  # robustly extract cover image, genres and description
  def extract_metadata_from_series_page
    begin
      @browser.go_to(@scrape_url)
      sleep(1)
      doc = Nokogiri::HTML(@browser.body)

      # Prefer .seriesimg > img
      img_el = doc.at_css('.seriesimg img') || doc.at_css('.seriesthumb img') || doc.at_css('meta[property="og:image"]')
      url = nil
      if img_el
        url = img_el['src'] || img_el['data-src'] || img_el['data-original'] || img_el['data-lazy'] || img_el['content']
        if url.blank? && img_el['srcset'].present?
          url = img_el['srcset'].split(',').first.split.first
        end
      end
      @novel_image_url = absolute_url(url.to_s.strip) if url.present?

      @novel_genres = doc.css('#seriesgenre a.genre').map { |a| a.text.to_s.strip }.reject(&:blank?)

      desc_el = doc.at_css('#editdescription') || doc.at_css('#seriesinfo #editdescription')
      if desc_el
        paras = desc_el.css('p').map { |p| p.text.to_s.strip }.reject(&:blank?)
        @novel_description = paras.join("\n\n") if paras.any?
      end

      Rails.logger.info "Scraped metadata: image=#{@novel_image_url.inspect}, genres=#{@novel_genres.inspect}, description_present=#{@novel_description.present?}"
    rescue => e
      Rails.logger.error "extract_metadata_from_series_page failed: #{e.class}: #{e.message}"
    end
  end

  def absolute_url(href)
    return href if href =~ /\Ahttp/i
    if href.start_with?('//')
      "https:#{href}"
    else
      URI.join(@scrape_url, href).to_s
    end
  rescue
    href
  end

  def process_scraped_data
    return unless @target_group && @chapter_data.any?

    Rails.logger.info "Processing scraped data for group: #{@target_group}"

    website = find_or_create_website
    novel = find_or_create_novel(website)

    if novel
      update_novel_metadata(novel)    # save image_url/description and attach image
      sync_positions_from_source(novel, @chapter_data)
    else
      Rails.logger.error "Could not find or create novel for #{@scrape_url}"
    end
  end

  def find_or_create_website
    website = Website.find_by(link: @group_link)
    return website if website
    Website.create!(name: @target_group, link: @group_link)
  end

  def find_or_create_novel(website)
    clean_novel_link = clean_novel_url
    return nil unless clean_novel_link

    novel = Novel.find_by(link: clean_novel_link, website: website)
    return novel if novel

    novel_name = extract_novel_name_from_url
    return nil unless novel_name

    Novel.create!(name: novel_name, link: clean_novel_link, website: website)
  end

  def clean_novel_url
    match = @scrape_url.match(%r{(https://www\.novelupdates\.com/series/[^/?]+)})
    if match
      "#{match[1]}/"
    else
      @scrape_url
    end
  end

  def extract_novel_name_from_url
    match = @scrape_url.match(%r{/series/([^/?]+)})
    if match
      match[1].gsub('-', ' ').titleize
    else
      nil
    end
  end

  # persist metadata (only save image URL and description, don't download/attach image)
  def update_novel_metadata(novel)
    begin
      novel.update!(description: @novel_description) if @novel_description.present?

      if @novel_image_url.present?
        # Save the remote URL reference (best-effort)
        novel.update_columns(image_url: @novel_image_url)
        Rails.logger.info "Saved image_url for novel #{novel.id}: #{@novel_image_url}"
      end

      if @novel_genres.any?
        if novel.respond_to?(:tag_list=)
          novel.tag_list = @novel_genres.join(', ')
          novel.save! if novel.changed?
        elsif defined?(Tag) && novel.respond_to?(:tags=)
          tag_records = @novel_genres.map { |n| Tag.find_or_create_by!(name: n.downcase.strip) }
          novel.tags = tag_records
        end
      end
    rescue => e
      Rails.logger.error "update_novel_metadata failed for novel #{novel&.id}: #{e.class}: #{e.message}"
    end
  end

  # Reconcile and set chapter positions based on source order (oldest->newest)
  def sync_positions_from_source(novel, source_chapter_list)
    return unless novel && source_chapter_list.present?

    source_list = source_chapter_list.map do |cd|
      { title: cd[:chapter_title].to_s.strip, link: cd[:chapter_url].to_s.strip }
    end

    source_list.reverse! if looks_newest_first?(source_list)

    ActiveRecord::Base.transaction do
      source_list.each_with_index do |cd, idx|
        pos = idx + 1
        title = cd[:title]
        link = cd[:link]

        chapter = Chapter.find_by(link: link, novel: novel) if link.present?
        chapter ||= Chapter.find_by(name: title, novel: novel)

        if chapter
          updates = {}
          updates[:name] = title if chapter.name != title
          updates[:link] = link if link.present? && chapter.link != link
          chapter.update_columns(updates) if updates.any?
          chapter.update_columns(position: pos) if chapter.position != pos
        else
          Chapter.create!(name: title, link: link, novel: novel, position: pos)
        end
      end

      max_pos = novel.chapters.maximum(:position) || source_list.length
      novel.chapters.where(position: nil).find_each do |ch|
        max_pos += 1
        ch.update_columns(position: max_pos)
      end
    end
  rescue => e
    Rails.logger.error "sync_positions_from_source failed: #{e.message}"
  end

  def looks_newest_first?(list)
    return false unless list.is_a?(Array) && list.size >= 2
    first_num = extract_chapter_number(list.first[:title])
    last_num  = extract_chapter_number(list.last[:title])
    return false unless first_num && last_num
    first_num > last_num
  end

  def extract_chapter_number(title)
    return nil unless title
    m = title.match(/chapter\s*([0-9]+(\.[0-9]+)?)/i) || title.match(/ch(?:\.)?\s*([0-9]+(\.[0-9]+)?)/i)
    m && m[1].to_f
  end

  def cleanup_browser
    @browser&.quit
  end
end