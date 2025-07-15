class WebsitesController < ApplicationController
    allow_unauthenticated_access only: %i[ index show ]
    before_action :set_website, only: %i[show edit update]
    
    def index
        @websites = Website.all
    end

    def show
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

    private
    def set_website
        @website = Website.find(params[:id])
    end


    def website_params
        params.expect(product: [ :name, :description, :featured_image, :novel_amount ])
    end

end
