require "canvas_qti_to_learnosity_converter/questions/question"

module CanvasQtiToLearnosityConverter
    class OrderingQuestion < QuizQuestion
        def to_learnosity
            {
                type: "orderlist",
                stimulus: extract_stimulus(),
                list: extract_items(), 
                validation: extract_validation(),
            }
        end

        def extract_items()
            @xml.css("item > presentation > response_lid > render_extension > ims_render_object > flow_label > response_label").map do |node|
                extract_mattext(node.css("material > mattext").first)
            end
        end

        def extract_validation()
            item_idents = @xml.css("item > presentation > response_lid > render_extension > ims_render_object > flow_label > response_label").map do |node|
                node.attribute("ident")&.value
            end.compact

            ordered_idents = @xml.css("item > resprocessing > respcondition[continue='No'] > conditionvar varequal").map(&:content)
                .map(&:strip)
                .reject(&:empty?)

            # Map each ordered ident to its index in the original list
            ordered_indices = ordered_idents.map do |ident|
              item_idents.index(ident)
            end.compact

            {
                "valid_response" => {
                    "score" => extract_points_possible,
                    "value" => ordered_indices
                }
            }
        end

        def add_learnosity_assets(assets, path, learnosity)
            process_assets!(
                assets,
                path,
                learnosity[:stimulus]
            )

            learnosity[:list].each.with_index do |item, index|
                process_assets!(
                    assets,
                    path,
                    item
                )
            end

            learnosity
        end
    end
end