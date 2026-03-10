require "canvas_qti_to_learnosity_converter/questions/question"

module CanvasQtiToLearnosityConverter
  class CategorizationQuestion < QuizQuestion
    def to_learnosity
      {
        type: "classification",
        stimulus: extract_stimulus(),
        possible_responses: extract_possible_responses(),
        ui_style: extract_ui_style(),
        validation: extract_validation(),
      }
    end

    def extract_possible_responses()
      item_index_map().keys.map { |ident| item_text_map()[ident] }
    end

    def extract_ui_style()
      categories = @xml.css("item > presentation > response_lid")
      {
        "column_count" => categories.length,
        "column_titles" => categories.map { |c| c.css("> material > mattext").first&.text || "" },
      }
    end

    def extract_validation()
      cat_idx = category_index_map()
      item_idx = item_index_map()

      column_values = Array.new(cat_idx.length) { [] }

      @xml.css("item > resprocessing > respcondition > conditionvar > varequal").each do |varequal|
        category_ident = varequal.attribute("respident")&.value
        item_ident = varequal.text.strip

        col = cat_idx[category_ident]
        row = item_idx[item_ident]
        next if col.nil? || row.nil?

        column_values[col] << row
      end

      {
        "scoring_type" => "exactMatch",
        "valid_response" => {
          "score" => extract_points_possible,
          "value" => column_values,
        }
      }
    end

    def add_learnosity_assets(assets, path, learnosity)
      process_assets!(assets, path, learnosity[:stimulus])
      learnosity
    end

    private

    # Returns { item_ident => index } in first-occurrence order across all categories
    def item_index_map()
      @item_index_map ||= begin
        map = {}
        index = 0
        @xml.css("item > presentation > response_lid > render_choice > response_label").each do |label|
          ident = label.attribute("ident")&.value
          next if ident.nil? || map.key?(ident)
          map[ident] = index
          index += 1
        end
        map
      end
    end

    # Returns { item_ident => display text }
    def item_text_map()
      @item_text_map ||= begin
        map = {}
        @xml.css("item > presentation > response_lid > render_choice > response_label").each do |label|
          ident = label.attribute("ident")&.value
          next if ident.nil? || map.key?(ident)
          map[ident] = label.css("material > mattext").first&.text || ""
        end
        map
      end
    end

    # Returns { category_ident => column_index }
    def category_index_map()
      @category_index_map ||= begin
        map = {}
        @xml.css("item > presentation > response_lid").each_with_index do |cat, i|
          ident = cat.attribute("ident")&.value
          map[ident] = i if ident
        end
        map
      end
    end
  end
end
