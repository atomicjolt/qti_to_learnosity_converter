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

    def add_learnosity_assets(assets, path)
      learnosity = to_learnosity
      CanvasQtiToLearnosityConverter.add_files_to_assets(
        assets,
        path + [:content],
        learnosity[:content]
      )
    end
  end
end
