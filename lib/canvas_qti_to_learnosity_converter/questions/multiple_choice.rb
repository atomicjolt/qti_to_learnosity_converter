require "canvas_qti_to_learnosity_converter/questions/question"

module CanvasQtiToLearnosityConverter
  class MultipleChoiceQuestion < QuizQuestion
    def extract_options()
      choices = @xml.css("item > presentation > response_lid > render_choice > response_label")
      choices.map do |choice|
        ident = choice.attribute("ident").value
        {
          "value" => ident,
          "label" => extract_mattext(choice.css("material > mattext").first),
        }
      end
    end

    def extract_response_id()
      @xml.css("item > presentation > response_lid").attribute("ident").value
    end

    def extract_validation()
      resp_conditions = @xml.css("item > resprocessing > respcondition")
      correct_condition = resp_conditions.select do |condition|
        setvar = condition.css("setvar")
        setvar.length === 1 && setvar.text === "100"
      end.first

      # TODO check for more than 1 element
      correct_value = correct_condition.css("varequal").text
      {
        "scoring_type" => "exactMatch",
        "valid_response" => {
          "value" => [correct_value],
          "score" => extract_points_possible,
        },
      }
    end

    def to_learnosity
      {
        stimulus: extract_stimulus(),
        options: extract_options(),
        multiple_responses: false,
        response_id: extract_response_id(),
        type: "mcq",
        validation: extract_validation(),
      }
    end

    def add_learnosity_assets(assets, path)
      learnosity = to_learnosity
      CanvasQtiToLearnosityConverter.add_files_to_assets(
        assets,
        path + [:stimulus],
        learnosity[:stimulus]
      )

      learnosity[:options].each.with_index do |option, index|
        CanvasQtiToLearnosityConverter.add_files_to_assets(
          assets,
          path + [:options, index, "label"],
          option["label"]
        )
      end
    end
  end

  class MultipleAnswersQuestion < MultipleChoiceQuestion
    def to_learnosity
      {
        stimulus: extract_stimulus(),
        options: extract_options(),
        multiple_responses: true,
        response_id: extract_response_id(),
        type: "mcq",
        validation: extract_validation()
      }
    end

    def extract_validation()
      correct_condition = @xml.css('item > resprocessing >
                                   respcondition[continue="No"] > conditionvar >
                                   and > varequal')
      alt_responses = correct_condition.map(&:text)
      {
        "scoring_type" => "partialMatchV2",
        "rounding" => "none",
        "penalty" => extract_points_possible,
        "valid_response" => {
          "score" => extract_points_possible,
          "value" => alt_responses,
        },
      }
    end
  end
end
