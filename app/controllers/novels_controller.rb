class NovelsController < ApplicationController
    allow_unauthenticated_access
    before_action :set_website, only: [:index, :new, :create]
    before_action :set_novel, only: [:show, :edit, :update]

    def index
        @novels = @website.novels
    end

    def show
    end

    def new
        @novel = @website.novels.build
    end

    def create
        @novel = @website.novel.build(novel_params)
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

    def set_website
        @website = Website.find(params[:website_id])
    end

    def set_novel
        @novel = Novel.find(params[:id])
    end

    def novel_params
        params.expect(novel: [ :name, :link ])
    end
end
