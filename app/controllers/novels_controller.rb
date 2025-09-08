class NovelsController < ApplicationController
    allow_unauthenticated_access only: %i[ show ]
    before_action :set_novel, only: [:show, :edit, :update]
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
