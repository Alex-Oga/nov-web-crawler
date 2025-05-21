class WebsitesController < ApplicationController
    
    def index
        @websites = Website.all
    end

    def show
        @website = Website.find(params[:id])
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
        @website = Website.find(params[:id])
    end

    def update
        @website = Website.find(params[:id])
        if @website.update(website_params)
            redirect_to @website, notice: 'Website was successfully updated.'
        else
            render :edit, status: :unprocessable_entity

    private
    def website_params
        params.expect(website: [:name, :url])
    end
end
