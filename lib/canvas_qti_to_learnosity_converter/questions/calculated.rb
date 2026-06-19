require "canvas_qti_to_learnosity_converter/questions/template_question"

module CanvasQtiToLearnosityConverter
  class CalculatedQuestion < TemplateQuestion
    def to_learnosity
      {
        type: "clozeformulaV2",
        is_math: true,
        is_dynamic_content: true,
        template: build_template_field(),
        validation: extract_validation(),
      }
    end

    def build_template_field()
      template = get_template()
      uses_backtick = template.match?(/`[^`]+`/)
      extract_var_names().each do |name|
        pattern = uses_backtick ? "`#{name}`" : "[#{name}]"
        template.sub!(pattern, "{{var:#{name}}}")
      end
      template.match?(/__{2,}/) ? template.sub(/__{2,}/, "{{response}}") : template + "{{response}}"
    end

    # New Quizzes exports variables with backtick notation (e.g. `w`),
    # while Classic Quizzes uses square bracket notation (e.g. [w]).
    # Detect which format is in use and return plain variable names either way.
    def extract_template_values(template)
      backtick_vars = template.scan(/`([^`]+)`/).map(&:first)
      backtick_vars.any? ? backtick_vars : super
    end

    def extract_validation()
      decimal_places = @xml.css("item > itemproc_extension > calculated > formulas")
        .first["decimal_places"].to_i

      if scientific_notation_enabled?
        {
          "scoring_type" => "exactMatch",
          "valid_response" => {
            "score" => extract_points_possible,
            "value" => [[
              {
                "method" => "equivValue",
                "value" => "{{var:scientific}}",
                "options" => {
                  "allowThousandsSeparator" => false,
                  "setThousandsSeparator" => [","],
                  "setDecimalSeparator" => ["."],
                }
              },
              {
                "method" => "equivSyntax",
                "value" => "\\format{\\scientific}",
                "options" => {
                  "allowThousandsSeparator" => false,
                  "setThousandsSeparator" => [","],
                  "setDecimalSeparator" => ["."],
                }
              }
            ]]
          }
        }
      else
        {
          "scoring_type" => "exactMatch",
          "valid_response" => {
            "score" => extract_points_possible,
            "value" => [[{
              "method" => "equivValue",
              "value" => "{{var:decimal}}",
              "options" => { "decimalPlaces" => decimal_places }
            }]]
          }
        }
      end
    end

    def item_metadata()
      {
        dynamic_content: build_dynamic_content(),
      }
    end

    def build_dynamic_content()
      var_names = extract_var_names()
      var_ranges = extract_var_ranges()
      formula = extract_formula()
      context = build_mqg_context()
      data = build_generated_math_data()
      count = data.length
      scientific = scientific_notation_enabled?
      response_name = scientific ? "scientific" : "decimal"

      first_row = data.first[:val]
      first_vars = first_row.reject { |v| v[:name] == response_name }
      first_answer = first_row.find { |v| v[:name] == response_name }&.dig(:val)
      seed_with_values = first_vars.reduce(formula) { |f, v| f.gsub(v[:name], v[:val]) }

      # scientific values are already formatted as LaTeX; decimal values need wrapping
      response_sample_val = scientific ? first_answer : (first_answer ? "\\(#{first_answer}\\)" : nil)

      sample = first_answer ? {
        val: [
          { name: "seed", val: "\\(#{seed_with_values}\\)" },
          { name: response_name, val: response_sample_val },
        ],
        length: 2,
        count: 1,
      } : nil

      {
        parameters: var_names.map do |name|
          range = var_ranges[name]
          { name: name, type: "range", min: range[:min], max: range[:max], step: range[:step] }
        end,
        generated_math: {
          type: "formula",
          sample: sample,
          seed: formula,
          response: [response_name],
          params: [var_names, var_names.map { |name|
            r = var_ranges[name]
            "#{r[:min]}..#{r[:max]}:#{r[:step]}"
          }],
          context: context,
          template: "{response==seed}",
          checks: [],
          count: count,
          limit: count,
          randomize: true,
          data: data,
        }.compact,
        question_data: build_question_data(),
        validation_data: build_validation_data(response_sample_val, scientific: scientific),
      }
    end

    def extract_var_names()
      @xml.css("item > itemproc_extension > calculated > vars > var").map { |v| v["name"] }
    end

    def extract_var_ranges()
      @xml.css("item > itemproc_extension > calculated > vars > var").each_with_object({}) do |v, hash|
        scale = v["scale"].to_i
        step = scale == 0 ? 1 : (10.0 ** -scale).round(scale)
        hash[v["name"]] = { min: v.css("min").first.text, max: v.css("max").first.text, step: step }
      end
    end

    def extract_formula()
      @xml.css("item > itemproc_extension > calculated > formulas > formula").first&.text || ""
    end

    def build_mqg_context()
      template = get_template()
      uses_backtick = template.match?(/`[^`]+`/)
      extract_var_names().each do |name|
        pattern = uses_backtick ? "`#{name}`" : "[#{name}]"
        template.sub!(pattern, "{#{name}}")
      end
      template.match?(/__{2,}/) ? template.sub(/__{2,}/, "{{response}}") : template
    end

    def build_generated_math_data()
      var_names = extract_var_names()
      var_values = var_names.map do |name|
        @xml.css(%{item > itemproc_extension > calculated > var_sets > var_set > var[name="#{name}"]}).map(&:text)
      end
      answers = @xml.css("item > itemproc_extension var_sets answer").map(&:text)
      scientific = scientific_notation_enabled?

      answers.each_with_index.map do |answer, i|
        row_vals = var_names.each_with_index.map { |name, j| { name: name, val: var_values[j][i] } }
        if scientific
          row_vals << { name: "scientific", val: format_scientific_latex(answer) }
        else
          row_vals << { name: "decimal", val: answer }
        end
        { val: row_vals }
      end
    end

    def build_question_data()
      formula = extract_formula()
      expression = extract_var_names().reduce(formula) do |f, name|
        f.gsub(/\b#{Regexp.escape(name)}\b/, "{{var:#{name}}}")
      end
      {
        expression: expression,
        template: build_template_field(),
      }
    end

    def build_validation_data(sample_val = nil, scientific: false)
      decimal_places = @xml.css("item > itemproc_extension > calculated > formulas")
        .first["decimal_places"].to_i

      if scientific
        {
          availableFormats: [{ name: "scientific", val: sample_val || "", isSelected: true }],
          formatsData: {
            scientific: {
              value: [[
                {
                  method: "equivValue",
                  value: "{{var:scientific}}",
                  options: {
                    allowThousandsSeparator: false,
                    setThousandsSeparator: [","],
                    setDecimalSeparator: ["."],
                  },
                },
                {
                  method: "equivSyntax",
                  value: "\\format{\\scientific}",
                  options: {
                    allowThousandsSeparator: false,
                    setThousandsSeparator: [","],
                    setDecimalSeparator: ["."],
                  },
                },
              ]]
            }
          },
          options: {
            score: extract_points_possible,
            decimalPlaces: decimal_places.to_s,
            allowThousandsSeparator: false,
            setDecimalSeparator: ".",
            setThousandsSeparator: ",",
          },
        }
      else
        {
          availableFormats: [{ name: "decimal", val: sample_val || "", isSelected: true }],
          formatsData: {
            decimal: {
              value: [[{
                method: "equivValue",
                value: "{{var:decimal}}",
                options: {
                  decimalPlaces: decimal_places,
                  allowThousandsSeparator: false,
                  setThousandsSeparator: [","],
                  setDecimalSeparator: ["."],
                },
              }]]
            }
          },
          options: {
            score: extract_points_possible,
            decimalPlaces: decimal_places.to_s,
            allowThousandsSeparator: false,
            setDecimalSeparator: ".",
            setThousandsSeparator: ",",
          },
        }
      end
    end

    def scientific_notation_enabled?
      @xml.css("item > itemproc_extension > calculated > formulas")
        .first&.[]("scientific_notation") == "true"
    end

    def format_scientific_latex(value_str)
      value = value_str.to_f
      return "\\(0\\)" if value == 0
      exp = Math.log10(value.abs).floor.to_i
      coefficient = value / 10.0 ** exp
      "\\(#{coefficient}\\times {10^{#{exp}}}\\)"
    end

    def widget_metadata()
      {
        name: "Math Question Generator",
        template_reference: "17149c09-83ba-4b1b-afff-a681e7edd8ff" # This is Learnosity's internal reference for the MQG widget;
      }
    end

    def add_learnosity_assets(assets, path, learnosity)
      process_assets!(assets, path, learnosity[:template])
      learnosity
    end

    def dynamic_content_data()
      var_names = extract_var_names()
      var_values = var_names.map do |name|
        @xml.css(%{item > itemproc_extension > calculated > var_sets > var_set > var[name="#{name}"]}).map(&:text)
      end
      answers = @xml.css("item > itemproc_extension var_sets answer").map(&:text)
      response_name = scientific_notation_enabled? ? "scientific" : "decimal"

      columns = var_names + ["seed", response_name]

      rows = Hash[answers.each_with_index.map do |answer, i|
        row_vals = var_names.each_with_index.map { |_, j| var_values[j][i] }
        row_vals << answer  # seed
        row_vals << answer  # response value
        [make_identifier(), { values: row_vals, index: i }]
      end]

      { cols: columns, rows: rows }
    end
  end
end
