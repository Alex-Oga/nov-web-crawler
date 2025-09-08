require 'nokogiri'
require 'open-uri'

class ChapterScraperService
  def initialize(chapter)
    @chapter = chapter
  end

  def scrape_content
    return parse_existing_content if @chapter.content.present?
    return ["No link provided"] unless @chapter.link.present?

    begin
      doc = Nokogiri::HTML(URI.open(@chapter.link))
      content = extract_main_content(doc)
      
      if content.any?
        @chapter.update(content: content.join("\n\n"))
        content
      else
        ["No content found"]
      end
    rescue Socket::ResolutionError, Net::TimeoutError => e
      Rails.logger.error "Failed to fetch content: #{e.message}"
      ["Content temporarily unavailable"]
    end
  end

  private

  def parse_existing_content
    @chapter.content.split("\n\n")
  end

  def extract_main_content(doc)
    # Get all paragraphs and group by parent class
    content_by_class = {}
    
    doc.css('p').each do |p|
      # Create a unique key based on the full path to avoid mixing content
      parent_path = p.ancestors.map { |a| a['class'] }.compact.join(' > ')
      parent_path = p.parent['class'] || 'no-class' if parent_path.empty?
      
      text = p.text.strip
      next if text.empty?
      
      content_by_class[parent_path] ||= []
      content_by_class[parent_path] << text
    end

    # Find the class with the largest total content
    largest_class = content_by_class.max_by { |class_name, paragraphs| 
      paragraphs.join(' ').length 
    }

    if largest_class
      Rails.logger.info "Selected class '#{largest_class[0]}' with #{largest_class[1].length} paragraphs"
      largest_class[1] # Return the paragraphs array
    else
      ["No content found"]
    end
  end
end