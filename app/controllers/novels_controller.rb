class NovelsController < ApplicationController
    allow_unauthenticated_access
    before_action :set_novel

    def index
        @novels = Novel.all
    end

    def show
        @novel = Novel.find(params[:id])
    end

    def new
        @novel = Novel.new
    end

    def create
        @novel = Novel.new(novel_params)
        if @novel.save
            redirect_to @novel, notice: "New Novel Registered."
        else
            render :new, status: :unprocessable_entity
        end
    end

    private

    def set_novel
    end

    def novel_params
        params.expect(novel: [ :name, :link ])
    end
end
