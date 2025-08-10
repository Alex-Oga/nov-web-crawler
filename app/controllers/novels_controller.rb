class NovelsController < ApplicationController
    allow_unauthenticated_access only: %i[ show ]
    before_action :setter, only: [:show, :edit, :update, :new, :create]

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

    def setter
        @novel = Novel.find(params[:id])
        @website = @novel.website
    end

    def novel_params
        params.expect(novel: [ :name, :link ])
    end
end
