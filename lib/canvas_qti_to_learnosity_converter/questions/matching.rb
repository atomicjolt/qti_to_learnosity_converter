require "canvas_qti_to_learnosity_converter/questions/question"

module CanvasQtiToLearnosityConverter
  class MatchingQuestion < QuizQuestion
    def to_learnosity
      {
        type: "association",
        stimulus: extract_stimulus(),
        stimulus_list: extract_stimulus_list(),
        validation: extract_validation(),
        possible_responses: extract_responses(),
        duplicate_responses: true,
      }
    end

    def extract_stimulus_list()
      @xml.css("item > presentation > response_lid > material > mattext").map do |node|
        extract_mattext(node)
      end
    end

    def extract_response_idents()
      @xml.css("item > presentation > response_lid").map do |node|
        node.attribute("ident").text
      end
    end

    def extract_valid_label_idents(valid_response_idents)
      valid_response_idents.map do |ident|
        @xml.css(%{item > resprocessing > respcondition varequal[respident="#{ident}"]}).map do |node|
          node.content
        end
      end.flatten
    end

    def extract_validation()
      valid_response_idents = extract_response_idents()
      valid_label_idents = extract_valid_label_idents(valid_response_idents)

      valid_idents = Hash[valid_response_idents.zip(valid_label_idents)]

      valid_responses = valid_idents.map do |response_ident, label_ident|
        @xml.css(%{item > presentation >
          response_lid[ident="#{response_ident}"]
          response_label[ident="#{label_ident}"] > material > mattext}).map do |node|
          extract_mattext(node)
        end
      end.flatten

      {
        "scoring_type" => "partialMatch",
        "valid_response" => {
          "value" => valid_responses
        }
      }
    end

    def extract_responses()
      response_node = @xml.css("item > presentation > response_lid").first

      response_node.css("response_label mattext").map do |node|
        extract_mattext(node)
      end
    end

    def add_learnosity_assets(assets, path)
      learnosity = to_learnosity
      CanvasQtiToLearnosityConverter.add_files_to_assets(
        assets,
        path + [:stimulus],
        learnosity[:stimulus]
      )
    end
  end
end
