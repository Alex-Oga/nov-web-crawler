# frozen_string_literal: true

# Handles following redirects from NovelUpdates to actual novel hosting sites.
# Includes Cloudflare challenge detection and manual resolution support.
module RedirectResolver
  extend ActiveSupport::Concern

  # Cloudflare challenge indicators in page content
  CLOUDFLARE_INDICATORS = [
    "Checking your browser",
    "cf-browser-verification",
    "cf_captcha_kind",
    "Cloudflare Ray ID",
    "DDoS protection by Cloudflare",
    "challenge-running",
    "cf-turnstile"
  ].freeze

  # Resolve a NovelUpdates redirect URL to the final destination URL.
  # Follows HTTP redirects and JavaScript-based redirects.
  #
  # @param redirect_url [String] The NovelUpdates extnu URL
  # @param browser [Ferrum::Browser] An active browser instance
  # @return [String] The final destination URL
  def resolve_final_url(redirect_url, browser)
    return redirect_url unless novelupdates_redirect?(redirect_url)

    Rails.logger.info "Resolving redirect: #{redirect_url}"

    browser.go_to(redirect_url)
    wait_for_redirect(browser)

    final_url = browser.current_url
    Rails.logger.info "Resolved to: #{final_url}"

    final_url
  rescue => e
    Rails.logger.error "Failed to resolve redirect #{redirect_url}: #{e.message}"
    redirect_url
  end

  # Check if URL is a NovelUpdates redirect link
  def novelupdates_redirect?(url)
    return false unless url.is_a?(String)
    url.include?("novelupdates.com/extnu/") ||
      url.include?("novelupdates.com/nu_go/")
  end

  # Wait for redirect to complete (URL changes from novelupdates.com)
  def wait_for_redirect(browser, max_attempts: 20, interval: 0.5)
    attempts = 0

    while attempts < max_attempts
      current_url = browser.current_url
      break unless current_url.include?("novelupdates.com")

      # Check for Cloudflare challenge
      if cloudflare_challenge_detected?(browser.body)
        handle_cloudflare_challenge(browser)
      end

      attempts += 1
      sleep(interval)
    end
  end

  # Detect if current page is a Cloudflare challenge
  def cloudflare_challenge_detected?(html)
    return false unless html.is_a?(String)

    CLOUDFLARE_INDICATORS.any? { |indicator| html.include?(indicator) }
  end

  # Handle Cloudflare challenge by waiting for manual resolution
  def handle_cloudflare_challenge(browser, timeout: nil)
    timeout ||= scraper_config[:cloudflare_timeout] || 120

    Rails.logger.warn "Cloudflare challenge detected! Waiting up to #{timeout}s for manual resolution..."
    Rails.logger.warn "Please solve the CAPTCHA in the browser window."

    start_time = Time.current
    while (Time.current - start_time) < timeout
      sleep(2)
      unless cloudflare_challenge_detected?(browser.body)
        Rails.logger.info "Cloudflare challenge resolved!"
        return true
      end
    end

    Rails.logger.error "Cloudflare challenge timeout after #{timeout}s"
    false
  end

  # Apply rate limiting delay between requests
  def apply_rate_limit(custom_delay: nil)
    delay = custom_delay || scraper_config[:request_delay] || 2
    Rails.logger.debug "Rate limiting: sleeping #{delay}s"
    sleep(delay)
  end

  # Get scraper configuration
  def scraper_config
    @scraper_config ||= Rails.application.config.scraper rescue default_scraper_config
  end

  private

  def default_scraper_config
    {
      request_delay: 2,
      cloudflare_timeout: 120,
      max_retries: 3,
      batch_size: 10
    }
  end
end
