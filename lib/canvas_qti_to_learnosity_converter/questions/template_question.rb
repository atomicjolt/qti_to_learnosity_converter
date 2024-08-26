require "canvas_qti_to_learnosity_converter/questions/question"

module CanvasQtiToLearnosityConverter
  class TemplateQuestion < QuizQuestion
    def extract_template()
      placeholders = @xml.css("item > presentation > response_lid > material >
        mattext").map { |text| extract_mattext(text) }

      template = get_template()

      placeholders.each do |placeholder|
        template.sub!("[#{placeholder}]", "{{response}}")
      end

      template
    end

    def extract_template_values(template)
      template.scan(/\[([^\]]+)\]/).map do |capture_list|
        capture_list.first
      end
    end

    def get_template()
      template_node_list = @xml.css("item > presentation > material > mattext")
      extract_mattext(template_node_list.first)
    end

    def add_learnosity_assets(assets, path, learnosity)
      process_assets!(
        assets,
        path,
        learnosity[:template]
      )
      learnosity
    end
  end
end
