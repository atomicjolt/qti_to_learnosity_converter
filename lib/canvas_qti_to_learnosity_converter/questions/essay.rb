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
