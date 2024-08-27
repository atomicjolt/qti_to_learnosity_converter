require "canvas_qti_to_learnosity_converter/questions/question"

module CanvasQtiToLearnosityConverter
  class TextOnlyQuestion < QuizQuestion
    def to_learnosity
      {
        type: "sharedpassage",
        heading: "",
        content: extract_stimulus(),
      }
    end

    def add_learnosity_assets(assets, path, learnosity)
      process_assets!(
        assets,
        path,
        learnosity[:content]
      )
      learnosity
    end
  end
end
