class WebsitesController < ApplicationController
    allow_unauthenticated_access only: %i[ index show ]
    before_action :set_website, only: %i[show edit update destroy]
    
    def index
        @websites = Website.all
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
