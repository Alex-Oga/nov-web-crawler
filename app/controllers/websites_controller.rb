class WebsitesController < ApplicationController
    allow_unauthenticated_access only: %i[ index show ]
    before_action :set_website, only: %i[show edit update destroy]
    
    def index
        @websites = Website.all
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
                sleep(2)
                
                # Navigate to the user-provided URL
                browser.go_to(params[:scrape_url])
                
                sleep(1)
                
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
                                
                                # Follow redirect to get actual URL
                                actual_url = follow_redirect(browser, chapter_url)
                                
                                @chapter_data << {
                                    group_name: group_name,
                                    chapter_title: chapter_title,
                                    chapter_url: actual_url
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
                        sleep(1)
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

    def show
        @novels = @website.novels
    end

    def new
        @website = Website.new
    end

    def create
        @website = Website.new(website_params)
        if @website.save
            redirect_to @website, notice: 'Website was successfully created.'
        else
            render :new, status: :unprocessable_entity
        end
    end

    def edit
    end

    def update
        if @website.update(website_params)
            redirect_to @website, notice: 'Website was successfully updated.'
        else
            render :edit, status: :unprocessable_entity
        end
    end

    def destroy
        @website.destroy
        redirect_to websites_path, notice: 'Website was successfully destroyed.'
    end

    private

    def set_website
        @website = Website.find(params[:id])
    end

    def website_params
        params.expect(website: [ :name, :link ])
    end

    at_exit do
        if defined?(@@browser) && @@browser
            @@browser.quit
        end
    end

    def follow_redirect(browser, redirect_url)
        begin
            # Make URL absolute if it starts with //
            if redirect_url.start_with?('//')
                redirect_url = "https:#{redirect_url}"
            elsif redirect_url.start_with?('/')
                redirect_url = "https://www.novelupdates.com#{redirect_url}"
            end
            
            # Create a new page/tab to follow the redirect
            new_page = browser.create_page
            new_page.go_to(redirect_url)
            
            sleep(0.5)

            final_url = redirect_url

            loop do
                # Get the final URL after redirect
                final_url = new_page.current_url

                break if new_page.current_url != redirect_url && new_page.current_url != 'about:blank'
                sleep(0.5)
            end
            
            # Close the new page
            new_page.close
            
            return final_url
            
        rescue => e
            Rails.logger.error "Error following redirect for #{redirect_url}: #{e.message}"
            # Return original URL if redirect fails
            return redirect_url
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

end
