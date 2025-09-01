require 'nokogiri'
require 'watir'
require 'uri'
require 'ferrum'

class NovelsController < ApplicationController
    allow_unauthenticated_access only: %i[ show ]
    before_action :set_novel, only: [:show, :edit, :update]
    before_action :set_website, only: [:new, :create] 

    def show
        @chapters = @novel.chapters
        @chapter_data = []

        if params[:scrape_url].present?
            begin
                browser = Ferrum::Browser.new(headless: false)
                browser.go_to("https://www.novelupdates.com/login/")
                
                # Wait for page to load and fill in login credentials
                browser.at_css('input[name="log"]').focus.type(ENV['SCRAPE_USERNAME'])
                browser.at_css('input[name="pwd"]').focus.type(ENV['SCRAPE_PASSWORD'])

                # Click login button
                browser.at_css('input[type="submit"]').click
                
                # Wait for login to complete
                sleep(3)
                
                # Navigate to the user-provided URL
                browser.go_to(params[:scrape_url])
                
                sleep(2)
                
                # Extract chapters from all pages
                loop do
                    # Get page source and parse with Nokogiri
                    page_source = browser.body
                    doc = Nokogiri::HTML(page_source)
                    
                    # Extract chapter data from the table using Nokogiri
                    rows = doc.css('#myTable tbody tr')
                    
                    if rows.empty?
                        Rails.logger.warn "No table rows found"
                        break
                    end
                    
                    rows.each do |row|
                        cells = row.css('td')
                        
                        if cells.length >= 3
                            # Extract group name and URL from second cell
                            group_link = cells[1].at_css('a')
                            group_name = group_link&.text&.strip || 'Unknown'
                            
                            # Extract chapter title and URL from third cell
                            chapter_link = cells[2].at_css('a')
                            
                            if chapter_link
                                chapter_title = chapter_link.text.strip
                                chapter_url = chapter_link['href']
                                
                                # Make sure URL is absolute
                                chapter_url = "#{chapter_url}" unless chapter_url.start_with?('http')
                                
                                @chapter_data << {
                                    group_name: group_name,
                                    chapter_title: chapter_title,
                                    chapter_url: chapter_url
                                }
                            end
                        end
                    end
                    
                    # Check for next page link
                    next_page_link = doc.at_css('a.next_page')
                    
                    if next_page_link && next_page_link['href']
                        next_url = next_page_link['href']
                        
                        # Make URL absolute if needed
                        if next_url.start_with?('./')
                            next_url = URI.join(params[:scrape_url], next_url).to_s
                        elsif !next_url.start_with?('http')
                            next_url = "https://www.novelupdates.com#{next_url}"
                        end
                        
                        # Navigate to next page
                        browser.go_to(next_url)
                        sleep(2)
                    else
                        break
                    end
                end
                
                Rails.logger.info "Extracted #{@chapter_data.length} chapters"
                
            rescue => e
                Rails.logger.error "Browser automation error: #{e.message}"
            ensure
                browser&.quit
            end
            
        end
    end

    def new
        @novel = @website.novels.build
    end

    def create
        @novel = @website.novels.build(novel_params)
        if @novel.save
            redirect_to @novel, notice: "New Novel Registered."
        else
            render :new, status: :unprocessable_entity
        end
    end

    def edit
    end
    
    def update
        if @novel.update(novel_params)
            redirect_to @novel, notice: "Novel was successfully updated."
        else
            render :edit, status: :unprocessable_entity
        end
    end

    private

    def set_novel
        @novel = Novel.find(params[:id])
    end

    def set_website
        @website = Website.find(params[:website_id])
    end

    def novel_params
        params.expect(novel: [ :name, :link ])
    end

    at_exit do
        if defined?(@@browser) && @@browser
            @@browser.quit
        end
    end

end
