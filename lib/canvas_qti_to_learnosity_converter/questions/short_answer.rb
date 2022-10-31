require "canvas_qti_to_learnosity_converter/questions/question"

module CanvasQtiToLearnosityConverter
  # This is fill in the blank in the Canvas UI, but it is actually a short
  # answer type.
  class ShortAnswerQuestion < QuizQuestion
    def extract_response_id()
      @xml.css("item > presentation > response_str").attribute("ident").value
    end

    def to_learnosity
      {
        type: "shorttext",
        stimulus: extract_stimulus(),
        validation: extract_validation(),
        response_id: extract_response_id(),
      }
    end

    def extract_validation()
      correct_responses = @xml.css('item > resprocessing >
        respcondition[continue="No"] > conditionvar > varequal')
      correct_response = { "value" => correct_responses.shift.text, "score" => extract_points_possible}
      {
        "scoring_type" => "exactMatch",
        "valid_response" => correct_response,
        "alt_responses" => correct_responses.map { |res| { "value" => res.text, "score" => extract_points_possible } }
      }
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
