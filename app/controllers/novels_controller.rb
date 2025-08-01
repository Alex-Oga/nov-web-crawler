class NovelsController < ApplicationController
    allow_unauthenticated_access
    before_action :set_novel

    def new
        @novel = Novel.new
    end
    
    def index
        @novels = Novel.all
    end 

    def show
    end

    def create
        @novel = Novel.new(novel_params)
        if @novel.save
            redirect_to @website, notice: "New Novel Registered."
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
