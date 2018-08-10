require "canvas_qti_to_learnosity_converter/questions/question"

module CanvasQtiToLearnosityConverter
  class NumericalQuestion < QuizQuestion
    def to_learnosity
      {
        is_math: true,
        type: "formulaV2",
        stimulus: extract_stimulus(),
        template: "{{response}}",
        validation: extract_validation(),
      }
    end

    def extract_validation()
      response_mins = @xml.css('item > resprocessing >
        respcondition[continue="No"] > conditionvar vargte').map do |node|
        node.content
      end

      response_maxs = @xml.css('item > resprocessing >
        respcondition[continue="No"] > conditionvar varlte').map do |node|
        node.content
      end

      answer_bounds = response_mins.zip(response_maxs).map do |bounds|
        puts bounds.inspect
        # Get the precision by counting the number of places after the decimal
        precision = [
          bounds.first.split(".").last.length,
          bounds.last.split(".").last.length
        ].max

        {
          center: ((bounds.first.to_f + bounds.last.to_f) / 2.0).round(precision),
          pm: ((bounds.first.to_f - bounds.last.to_f) / 2.0).round(precision).abs,
        }
      end

      valid_answers = answer_bounds.map do |bounds|
        {
          "value" => [{
            "method" => "equivValue",
            "value" => "#{bounds[:center]}\\pm#{bounds[:pm]}",
          }]
        }
      end

      {
        "scoring_type" => "exactMatch",
        "valid_response" => valid_answers.shift,
        "alt_responses" => valid_answers,
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
