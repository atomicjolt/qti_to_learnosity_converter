require "canvas_qti_to_learnosity_converter/questions/question"

module CanvasQtiToLearnosityConverter
  class FileUploadQuestion < QuizQuestion
    def to_learnosity
      {
        type: "fileupload",
        stimulus: extract_stimulus(),
        validation: {
          max_score: extract_points_possible,
        },
        allow_pdf: true,
        allow_jpg: true,
        allow_gif: true,
        allow_png: true,
        allow_csv: true,
        allow_rtf: true,
        allow_txt: true,
        allow_xps: true,
        allow_ms_word: true,
        allow_ms_excel: true,
        allow_ms_powerpoint: true,
        allow_ms_publisher: true,
        allow_open_office: true
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
