# Nov — Web crawler & reader

A small Rails app for scraping and reading translated web novels.

Quick links
- Code: [app/](app/)
- Scraper services: [app/services/novel_updates_scraper_service.rb](app/services/novel_updates_scraper_service.rb), [app/services/chapter_scraper_service.rb](app/services/chapter_scraper_service.rb), [app/services/batch_chapter_scraper_service.rb](app/services/batch_chapter_scraper_service.rb)
- Routes (web UI / scraping endpoints): [config/routes.rb](config/routes.rb)
- Setup script: [bin/setup](bin/setup)
- Docker entrypoint / image: [bin/docker-entrypoint](bin/docker-entrypoint), [Dockerfile](Dockerfile)
- Gemfile: [Gemfile](Gemfile)
- Schema reference: [db/schema.rb](db/schema.rb)

Prerequisites
- Ruby: see [.ruby-version](.ruby-version)
- Bundler, Node/Yarn (if editing frontend assets), SQLite3 (dev) or your chosen DB
- Optional: headless browser dependencies for scrapers (Ferrum / Watir / webdrivers)

Local setup (development)
1. Install gems:
   bundle install
3. Run the project setup (creates, migrates DB, seeds if any):
   bin/setup
4. Start the server:
   bin/rails server
6. Run tests:
   bin/rails test

Environment
- Put local env vars in `.env` (loaded by [dotenv-rails](Gemfile)).
- Scraper credentials (optional) used by [app/services/novel_updates_scraper_service.rb](app/services/novel_updates_scraper_service.rb):
  - SCRAPE_USERNAME
  - SCRAPE_PASSWORD
- For production Docker usage set RAILS_MASTER_KEY and production env vars.

Using the scrapers
- Add/import websites/novels via the web UI (see [config/routes.rb](config/routes.rb)).
- Batch chapter scraping is available from the novel show page (POST to member `batch_scrape`) and the site exposes a collection `scrape_content` endpoint for websites.

Deploy
- Container build: see [Dockerfile](Dockerfile).
- If using Kamal, see `.kamal/` hooks and `bin/kamal` for deployment helpers.

Contributing / Notes
- Keep scraper browser options and timeouts under test when running at scale (see Ferrum usage in [app/services/chapter_scraper_service.rb](app/services/chapter_scraper_service.rb)).
- Report issues or add README improvements via PR.

Files referenced above can be opened directly in this workspace.
