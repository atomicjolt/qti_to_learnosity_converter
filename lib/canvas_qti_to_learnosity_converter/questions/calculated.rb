require "canvas_qti_to_learnosity_converter/questions/template_question"

module CanvasQtiToLearnosityConverter
  class CalculatedQuestion < TemplateQuestion
    def to_learnosity
      {
        type: "clozeformula",
        is_math: true,
        stimulus: extract_stimulus(),
        template: "{{response}}",
        validation: extract_validation(),
      }
    end

    def extract_stimulus()
      template = get_template()
      extract_template_values(template).each.with_index do |var_name, index|
        template.sub!("[#{var_name}]", "{{var:val#{index}}}")
      end

      template
    end

    def extract_validation()
      pm = @xml.css("item > itemproc_extension > calculated > answer_tolerance")
        .first.text

      {
        "scoring_type" => "exactMatch",
        "valid_response" => {
          "value" => [[{
            "method" => "equivValue",
            "value" => "{{var:answer}}\\pm#{pm}"
          }]]
        }
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

    def dynamic_content_data()
      values = extract_dynamic_content_data()

      columns = (0...(values.first.count - 1)).map{ |x| "val#{x}" }
      columns.push("answer")

      rows = Hash[values.map.with_index do |row, index|
        [make_identifier(), { values: row, index: index }]
      end]

      { cols: columns, rows: rows }
    end

    def extract_dynamic_content_data()
      template = get_template()
      vars = extract_template_values(template).map do |var_name|
        @xml.css(%{item > itemproc_extension > calculated > var_sets >
          var_set > var[name="#{var_name}"]}).map { |node| node.text }
      end

      answers = @xml.css("item > itemproc_extension var_sets answer").map do |node|
        node.text
      end

      vars.push(answers).transpose
    end
  end
end
