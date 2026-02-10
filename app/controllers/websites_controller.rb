require 'nokogiri'
require 'watir'
require 'uri'
require 'ferrum'

class WebsitesController < ApplicationController
    allow_unauthenticated_access only: %i[ index show ]
    before_action :set_website, only: %i[show edit update destroy]
    
    def index
        @websites = Website.all
        @chapter_data = []
        @scrape_error = nil

        if params[:scrape_url].present?
        scraper = NovelUpdatesScraperService.new(params[:scrape_url])
        @chapter_data = scraper.scrape_chapters
        
        if @chapter_data.empty?
            @scrape_error = "Invalid URL or scraping failed. Please use a NovelUpdates series URL."
        end
    end
    end
    
    def scrape_content
        @websites = Website.all
        @chapter_data = []
        
        # Run batch scraping
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
end