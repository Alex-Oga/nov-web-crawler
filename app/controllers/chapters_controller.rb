require 'nokogiri'
require 'open-uri'

class ChaptersController < ApplicationController
    allow_unauthenticated_access only: %i[ show ]
    before_action :set_chapter, only: [:show, :edit, :update]
    before_action :set_novel, only: [:new, :create] 

    def show
        begin
            if (@chapter.link.present? && !@chapter.content.present?)
                doc = Nokogiri::HTML(URI.open(@chapter.link))
            
                # Get all paragraphs and group by parent class
                content_by_class = {}
                
                doc.css('p').each do |p|
                    # Create a unique key based on the full path to avoid mixing content
                    parent_path = p.ancestors.map { |a| a['class'] }.compact.join(' > ')
                    parent_path = p.parent['class'] || 'no-class' if parent_path.empty?
                    
                    text = p.text.strip
                    next if text.empty?
                    content_by_class[parent_path] ||= []
                    content_by_class[parent_path] << text
                end
                # Find the class with the largest total content
                largest_class = content_by_class.max_by { |class_name, paragraphs| 
                    paragraphs.join(' ').length 
                }
            
                if largest_class
                    @content = largest_class[1] # Get the paragraphs array
                    Rails.logger.info "Selected class '#{largest_class[0]}' with #{@content.length} paragraphs"
                    @chapter.update(content: @content.join("\n\n"))
                else
                    @content = ["No content found"]
                end
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
