require "canvas_qti_to_learnosity_converter/questions/template_question"

module CanvasQtiToLearnosityConverter
  class MixedFillBlanksTypeError < StandardError
    def initialize
      super("Question contains both fill-in-the-blank and dropdown/wordbank responses. " \
            "Please separate them into distinct questions before importing.")
    end
  end

  # Canvas New Quizzes combines typed-text blanks (openEntry), dropdown menus, and
  # word banks all under the single fill_in_multiple_blanks_question QTI type.
  # Since Learnosity requires a distinct question type for each interaction style,
  # this class acts as a dispatcher: it inspects the answer_type attributes on the
  # response_labels and returns the appropriate subclass instance.
  class FillTheBlanksQuestion
    def self.for(xml)
      types = xml.css("item > presentation > response_lid").map do |lid|
        first_label = lid.css("render_choice > response_label").first
        case first_label&.attribute("answer_type")&.value
        when "dropdown" then :dropdown
        when "wordbank" then :wordbank
        else                 :blank
        end
      end.uniq

      raise MixedFillBlanksTypeError if types.size > 1

      case types.first
      when :dropdown then FillBlanksDropdownQuestion.new(xml)
      when :wordbank  then FillBlanksWordBankQuestion.new(xml)
      else                 FillBlanksTextQuestion.new(xml)
      end
    end
  end

  # Handles fill_in_multiple_blanks_question where all blanks are typed-text
  # (answer_type="openEntry" in New Quizzes, or no answer_type in Classic Quizzes).
  # Produces a Learnosity clozetext question with combinatorial alt_responses
  # to cover every accepted-answer combination across all blanks.
  class FillBlanksTextQuestion < TemplateQuestion
    def to_learnosity
      {
        type: "clozetext",
        stimulus: "",
        template: extract_template(),
        validation: extract_validation(),
      }
    end

    private

    def extract_validation
      template = get_template()

      responses = extract_template_values(template).map do |name|
        result = @xml.css(%{item > presentation >
          response_lid[ident="response_#{name}"] > render_choice material >
          mattext}).map do |node|
          extract_mattext(node)
        end

        result.empty? ? nil : result
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

  # Handles fill_in_multiple_blanks_question where all blanks are word bank
  # (answer_type="wordbank" in New Quizzes). Canvas exports a shared pool of
  # choices repeated identically across every response_lid. Produces a Learnosity
  # clozeassociation question with a flat possible_responses list and per-blank
  # correct answers expressed as single-element arrays.
  class FillBlanksWordBankQuestion < TemplateQuestion
    def to_learnosity
      {
        type: "clozeassociation",
        stimulus: "",
        template: extract_template(),
        validation: extract_validation(),
        possible_responses: extract_responses(),
      }
    end

    private

    def extract_validation
      template = get_template()

      valid_responses = extract_template_values(template).map do |name|
        correct_ident = @xml.css(%{item > resprocessing > respcondition >
          conditionvar > varequal[respident="response_#{name}"]}).first&.content

        @xml.css(%{item > presentation >
          response_lid[ident="response_#{name}"] response_label}).map do |node|
          text = extract_mattext(node.css("mattext").first)
          ident = node.attribute("ident").text
          ident == correct_ident ? text : nil
        end.compact.first
      end.compact

      {
        "scoring_type" => "partialMatchV2",
        "rounding" => "none",
        "valid_response" => {
          "value" => valid_responses,
          "score" => extract_points_possible,
        }
      }
    end

    def extract_responses
      first_lid = @xml.css("item > presentation > response_lid").first
      return [] unless first_lid

      seen = {}
      first_lid.css("render_choice mattext").filter_map do |node|
        text = extract_mattext(node)
        next if seen[text]
        seen[text] = true
        text
      end
    end
  end

  # Handles fill_in_multiple_blanks_question where all blanks are choice-based
  # (answer_type="dropdown" in New Quizzes). Each response_lid has its own
  # distinct set of choices. Produces a Learnosity clozedropdown question.
  class FillBlanksDropdownQuestion < TemplateQuestion
    def to_learnosity
      {
        type: "clozedropdown",
        stimulus: "",
        template: extract_template(),
        validation: extract_validation(),
        possible_responses: extract_responses(),
      }
    end

    private

    def extract_validation
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

    def extract_responses
      template = get_template()

      extract_template_values(template).map do |name|
        result = @xml.css(%{item > presentation >
          response_lid[ident="response_#{name}"] > render_choice mattext}).map do |node|
          extract_mattext(node)
        end

        result.empty? ? nil : result
      end.compact
    end
  end
end
