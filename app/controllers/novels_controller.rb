class NovelsController < ApplicationController
    allow_unauthenticated_access
    before_action :set_novel
    
    def create
        @product.novels.where(novel_params).first_or_create
        redirect_to @product, notice: "New Novel Registered."
    end

    private

    def set_novel
        @novel = Website.find(params[:website_id])
    end

    def novel_params
        params.expect(novel: [ :link ])
    end
end
