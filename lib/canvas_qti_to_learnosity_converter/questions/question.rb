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

    def extract_mattext(mattext_node)
      mattext_node.content
    end

    def make_identifier()
      SecureRandom.uuid
    end
  end
end
