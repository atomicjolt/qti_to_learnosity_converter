require "canvas_qti_to_learnosity_converter/questions/question"

module CanvasQtiToLearnosityConverter
  class EssayQuestion < QuizQuestion
    def to_learnosity
      {
        type: "longtextV2",
        stimulus: extract_stimulus(),
        validation: {
          max_score: extract_points_possible,
        },
      }
    end

    def add_learnosity_assets(assets, path, learnosity)
      process_assets!(
        assets,
        path,
        learnosity[:stimulus]
      )
      learnosity
    end
  end
end
