# frozen_string_literal: true

# Load scraper configuration from config/scraper.yml
scraper_config_path = Rails.root.join("config", "scraper.yml")

if File.exist?(scraper_config_path)
  scraper_config = YAML.load_file(scraper_config_path, aliases: true)[Rails.env]
  Rails.application.config.scraper = scraper_config.deep_symbolize_keys
else
  Rails.logger.warn "Scraper config not found at #{scraper_config_path}, using defaults"
  Rails.application.config.scraper = {
    request_delay: 2,
    cloudflare_timeout: 120,
    max_retries: 3,
    batch_size: 10,
    content_load_timeout: 5,
    max_browsers: 1
  }
end
