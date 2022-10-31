require "securerandom"

module CanvasQtiToLearnosityConverter
  class QuizQuestion
    extend Forwardable
    def_delegators :@xml, :css

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
  end
end
