require "securerandom"

module CanvasQtiToLearnosityConverter
  class QuizQuestion
    extend Forwardable
    def_delegators :@xml, :css

    def self.for(xml)
      new(xml)
    end

    def initialize(xml)
      @xml = xml
    end

    def extract_stimulus()
      mattext = @xml.css("item > presentation > material > mattext").first
      extract_mattext(mattext)
    end

    def extract_points_possible
      @xml.css(%{ item > itemmetadata > qtimetadata >
        qtimetadatafield > fieldlabel:contains("points_possible")})
        &.first&.next&.text&.to_f || 1.0
    end

    def extract_mattext(mattext_node)
      mattext_node.content
    end

    def make_identifier()
      SecureRandom.uuid
    end

    def dynamic_content_data()
      {}
    end

    def process_assets!(assets, path, text)
      doc = Nokogiri::XML.fragment(text)
      changed = false
      doc.css("img").each do |node|
        source = node["src"]
        next if !source

        source = URI::DEFAULT_PARSER.unescape(source)
        if /^\$IMS-CC-FILEBASE\$(.*)/.match(source) || /^((?!https?:).*)/.match(source)
          if source.start_with?("$IMS-CC-FILEBASE$")
            path = ''
          end
          asset_path = $1
          asset_path = asset_path.split("?").first.gsub(/^\//, '')
          asset_path = File.join(path, asset_path)
          clean_ext = File.extname(asset_path).gsub(/[^a-z0-9_.-]/i, '')
          assets[asset_path] ||= "#{SecureRandom.uuid}#{clean_ext}"
          node["src"] = "___EXPORT_ROOT___/assets/#{assets[asset_path]}"
          changed = true
        end
      end
      doc.css("audio").each do |node|
        source_node = node.css("source").first
        raw_src = source_node&.[]("src") || node["src"]
        next unless raw_src

        src = URI::DEFAULT_PARSER.unescape(raw_src)
        if /^\$IMS-CC-FILEBASE\$(.*)/.match(src) || /^((?!https?:).*)/.match(src)
          asset_path_base = src.start_with?("$IMS-CC-FILEBASE$") ? '' : path
          asset_path = $1.split("?").first.gsub(/^\//, '')
          asset_path = File.join(asset_path_base, asset_path)
          clean_ext = File.extname(asset_path).gsub(/[^a-z0-9_.-]/i, '')
          assets[asset_path] ||= "#{SecureRandom.uuid}#{clean_ext}"
          src = "___EXPORT_ROOT___/assets/#{assets[asset_path]}"
        end

        span = Nokogiri::XML::Node.new("span", doc)
        span["class"] = "learnosity-feature"
        span["data-player"] = "bar"
        span["data-simplefeature_id"] = SecureRandom.uuid
        span["data-src"] = src
        span["data-type"] = "audioplayer"
        span.add_child(Nokogiri::XML::Text.new("", doc))
        node.replace(span)
        changed = true
      end
      text.replace(doc.to_xml) if changed
    end

    def convert(assets, path)
      object = to_learnosity
      add_learnosity_assets(assets, path, object)
    end
  end
end
