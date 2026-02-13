class NovelsController < ApplicationController
    allow_unauthenticated_access only: %i[ show ]
    #before_action :require_admin, only: %i[ new create edit update ]
    before_action :set_novel, only: [:show, :edit, :update, :batch_scrape]
    before_action :set_website, only: [:new, :create] 

    def show
        @chapters = @novel.chapters
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

    def destroy
        @novel = Novel.find(params[:id])
        website = @novel.website
        @novel.destroy
        redirect_to website, notice: "Novel was successfully deleted."
    end

    def batch_scrape
        chapters_to_scrape = @novel.chapters.where(content: [nil, ''])
        scraper = BatchChapterScraperService.new(chapters_to_scrape)
        @scrape_results = scraper.scrape_all_content
        redirect_to @novel, notice: "Batch scrape completed for this novel."
    end

    def search
        if params[:tags].present?
            # If you want novels that have all tags:
            @novels = Novel.with_all_tags(params[:tags])
            # Or to match any tag, use:
            # @novels = Novel.with_any_tags(params[:tags])
        else
            @novels = Novel.all
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

end
