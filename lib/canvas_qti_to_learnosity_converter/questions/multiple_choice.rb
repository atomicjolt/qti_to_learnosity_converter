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
      
      # Extract all conditions that award points
      scored_conditions = resp_conditions.filter_map do |condition|
        setvar = condition.css("setvar").first
        next unless setvar
        
        score = setvar.text.to_f
        next if score <= 0
        
        answer_value = condition.css("varequal").text
        next if answer_value.empty?
        
        {
          value: answer_value,
          score: score
        }
      end.sort_by { |c| -c[:score] } # Sort by score descending
      
      return nil if scored_conditions.empty?
      
      # Get the highest scoring answer
      best_answer = scored_conditions.first
      points_possible = extract_points_possible
      
      # Helper method to scale score to points_possible
      scale_score = ->(score) { [score, points_possible].min }
      
      # If there's only one scoring option, use exactMatch
      if scored_conditions.length == 1
        {
          "scoring_type" => "exactMatch",
          "valid_response" => {
            "value" => [best_answer[:value]],
            "score" => scale_score.call(best_answer[:score]),
          },
        }
      else
        # Multiple scoring options, use partialMatch
        validation = {
          "scoring_type" => "partialMatch",
          "valid_response" => {
            "value" => [best_answer[:value]],
            "score" => scale_score.call(best_answer[:score]),
          },
        }
        
        # Add alternative responses with lower scores
        alt_responses = scored_conditions[1..].map do |condition|
          {
            "value" => [condition[:value]],
            "score" => scale_score.call(condition[:score]),
          }
        end
        
        validation["alt_responses"] = alt_responses if alt_responses.any?
        validation
      end
    end

    def to_learnosity
      shuffle = @xml.css("item > presentation > response_lid > render_choice").first&.attribute("shuffle")&.value
      {
        stimulus: extract_stimulus(),
        options: extract_options(),
        multiple_responses: false,
        shuffle_options: shuffle == "Yes",
        response_id: extract_response_id(),
        type: "mcq",
        validation: extract_validation(),
      }
    end

    def add_learnosity_assets(assets, path, learnosity)
      process_assets!(
        assets,
        path,
        learnosity[:stimulus]
      )

      learnosity[:options].each.with_index do |option, index|
        process_assets!(
          assets,
          path,
          option["label"]
        )
      end
      learnosity
    end
  end

  class MultipleAnswersQuestion < MultipleChoiceQuestion
    def to_learnosity
      shuffle = @xml.css("item > presentation > response_lid > render_choice").first&.attribute("shuffle")&.value
      {
        stimulus: extract_stimulus(),
        options: extract_options(),
        multiple_responses: true,
        shuffle_options: shuffle == "Yes",
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
