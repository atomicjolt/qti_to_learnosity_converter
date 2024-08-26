require "canvas_qti_to_learnosity_converter/questions/template_question"

module CanvasQtiToLearnosityConverter
  class FillTheBlanksQuestion < TemplateQuestion
    def to_learnosity
      {
        type: "clozetext",
        stimulus: "",
        template: extract_template(),
        validation: extract_validation(),
      }
    end

    def add_learnosity_assets(assets, path, learnosity)
      process_assets!(
        assets,
        path,
        learnosity[:template]
      )
      learnosity
    end

    def extract_validation()
      template = get_template()

      responses = extract_template_values(template).map do |name|
        result = @xml.css(%{item > presentation >
          response_lid[ident="response_#{name}"] > render_choice material >
          mattext}).map do |node|
          extract_mattext(node)
        end

        if result.empty?
          nil
        else
          result
        end
      end.compact

      all_responses = []
      create_responses(responses, 0, all_responses, [])

      {
        "scoring_type" => "partialMatchV2",
        "rounding" => "none",
        "valid_response" => all_responses.shift,
        "alt_responses" => all_responses
      }
    end

    def create_responses(blank_responses, depth, result, current_response)
      if depth == blank_responses.count
        result.push({ "score" => extract_points_possible, "value" => current_response })
        return
      end

      blank_responses[depth].each do |possible_response|
        create_responses(blank_responses, depth + 1, result, current_response + [possible_response])
      end
    end
  end
end
