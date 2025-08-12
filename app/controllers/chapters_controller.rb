require 'nokogiri'
require 'open-uri'

class ChaptersController < ApplicationController
    allow_unauthenticated_access only: %i[ show ]
    before_action :set_chapter, only: [:show, :edit, :update]
    before_action :set_novel, only: [:new, :create] 

    def show
        begin
            if @chapter.link.present?
                doc = Nokogiri::HTML(URI.open(@chapter.link))
                @content = doc.css('p').map(&:text)
            end
        rescue Socket::ResolutionError, Net::TimeoutError => e
            Rails.logger.error "Failed to fetch content: #{e.message}"
            @content = ["Content temporarily unavailable"]
        end
    end

    def new
        @chapter = @novel.chapters.build
    end

    def create
        @chapter = @novel.chapters.build(chapter_params)
        if @chapter.save
            redirect_to @chapter, notice: "New Chapter Registered."
        else
            render :new, status: :unprocessable_entity
        end
    end

    def edit
    end

    def update
        if @chapter.update(chapter_params)
            redirect_to @chapter, notice: "Chapter was successfully updated."
        else
            render :edit, status: :unprocessable_entity
        end
    end

    private

    def set_chapter
        @chapter = Chapter.find(params[:id])
    end

    def set_novel
        @novel = Novel.find(params[:novel_id])
    end

    def chapter_params
        params.expect(chapter: [ :name, :link, :content ])
    end
end
