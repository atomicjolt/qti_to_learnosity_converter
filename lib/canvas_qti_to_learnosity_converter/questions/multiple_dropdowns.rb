require "canvas_qti_to_learnosity_converter/questions/template_question"

module CanvasQtiToLearnosityConverter
  class MultipleDropdownsQuestion < TemplateQuestion
    def to_learnosity
      {
        type: "clozedropdown",
        stimulus: "",
        template: extract_template(),
        validation: extract_validation(),
        possible_responses: extract_responses(),
      }
    end

    def extract_validation()
      template = get_template()

      valid_responses = extract_template_values(template).map do |name|
        correct_ident = @xml.css(%{item > resprocessing > respcondition >
          conditionvar > varequal[respident="response_#{name}"]}).first&.content

        @xml.css(%{item > presentation >
          response_lid[ident="response_#{name}"] response_label}).map do |node|
          text = extract_mattext(node.css("mattext").first)
          ident = node.attribute("ident").text
          ident == correct_ident ? text : nil
        end.compact
      end.flatten

      {
        "scoring_type" => "partialMatchV2",
        "rounding" => "none",
        "valid_response" => {
          "value" => valid_responses,
          "score" => extract_points_possible,
        }
      }
    end

    def extract_responses()
      template = get_template()

      extract_template_values(template).map do |name|
        result = @xml.css(%{item > presentation >
          response_lid[ident="response_#{name}"] > render_choice mattext}).map do |node|
          extract_mattext(node)
        end

        if result.empty?
          nil
        else
          result
        end
      end.compact
    end
  end
end
