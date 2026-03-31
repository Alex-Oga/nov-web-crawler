require "nokogiri"
require "watir"
require "uri"
require "ferrum"

class WebsitesController < ApplicationController
    include AdminAuthorization

    allow_unauthenticated_access only: %i[ index show ]
    before_action :require_admin, only: %i[ new create edit update destroy scrape_content ]
    before_action :set_website, only: %i[show edit update destroy]

    def index
        @websites = Website.all
        @chapter_data = []
        @scrape_error = nil
        @scrape_queued = false

        if params[:scrape_url].present?
            # Queue background job for async scraping
            ScrapeNovelJob.perform_later(params[:scrape_url], scrape_content: params[:scrape_content] == "1")
            @scrape_queued = true
            flash.now[:notice] = "Scraping job queued. Chapters will appear shortly."
        end
    end

    def scrape_content
        @websites = Website.all
        @chapter_data = []

        # Admin-only batch scraping
        scraper = BatchChapterScraperService.new
        @scrape_results = scraper.scrape_all_content

        render :index
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
            redirect_to @website, notice: "Website was successfully created."
        else
            render :new, status: :unprocessable_entity
        end
    end

    def edit
    end

    def update
        if @website.update(website_params)
            redirect_to @website, notice: "Website was successfully updated."
        else
            render :edit, status: :unprocessable_entity
        end
    end

    def destroy
        @website.destroy
        redirect_to websites_path, notice: "Website was successfully destroyed."
    end

    private

    def set_website
        @website = Website.find(params[:id])
    end

    def website_params
        params.expect(website: [ :name, :link ])
    end
end
