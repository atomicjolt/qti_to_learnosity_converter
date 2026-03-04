require "canvas_qti_to_learnosity_converter/questions/question"

module CanvasQtiToLearnosityConverter
    class HotSpotQuestion < QuizQuestion
        def to_learnosity
            areas, area_attributes = extract_areas_and_attributes()

            result = {
                type: "hotspot",
                stimulus: extract_stimulus(),
                areas: areas,
                area_attributes: area_attributes,
                validation: extract_validation(areas.length),
            }

            image = extract_image()
            result[:image] = image if image

            result
        end

        def extract_stimulus()
            mattext = @xml.css("item > presentation > flow > response_xy > material > mattext").first
            return extract_mattext(mattext) if mattext
        end

        def extract_image()
            matimage = @xml.css("item > presentation > flow > response_xy > render_hotspot > material > matimage").first
            return nil unless matimage

            uri = matimage.attribute("uri")&.value
            return nil unless uri

            { source: uri }
        end

        def convert_coords_to_points(rarea, coords_str)
            coords = coords_str.split(",").map(&:to_f)

            case rarea
            when "ellipse"
                cx, cy, rx, ry = coords
                num_points = 12
                (0...num_points).map do |i|
                    angle = 2 * Math::PI * i / num_points
                    {
                        "x" => (cx + rx * Math.cos(angle)) * 100,
                        "y" => (cy + ry * Math.sin(angle)) * 100,
                    }
                end
            when "polygon"
                coords.each_slice(2).map do |x, y|
                    { "x" => x * 100, "y" => y * 100 }
                end
            else
                # rectangle (default): x1,y1,x2,y2
                x1, y1, x2, y2 = coords
                [
                    { "x" => x1 * 100, "y" => y1 * 100 },
                    { "x" => x2 * 100, "y" => y1 * 100 },
                    { "x" => x2 * 100, "y" => y2 * 100 },
                    { "x" => x1 * 100, "y" => y2 * 100 },
                ]
            end
        end

        def extract_areas_and_attributes()
            response_labels = @xml.css("item > presentation > flow > response_xy > render_hotspot > response_label")

            areas = []
            individual_attrs = []

            response_labels.each_with_index do |label, index|
                rarea = label.attribute("rarea")&.value || "rectangle"
                coords_str = label.text.strip
                ident = label.attribute("ident")&.value || index.to_s

                areas << convert_coords_to_points(rarea, coords_str)
                individual_attrs << { "area" => index.to_s, "label" => ident }
            end

            area_attributes = {
                "global" => {
                    "fill" => "rgba(255,255,255,0)",
                    "stroke" => "rgba(15,61,109,0.8)"
                },
                "individual" => individual_attrs
            }

            [areas, area_attributes]
        end

        def extract_validation(area_count)
            valid_indices = (0...area_count).map(&:to_s)

            {
                "scoring_type" => "exactMatch",
                "valid_response" => {
                    "score" => extract_points_possible,
                    "value" => valid_indices,
                }
            }
        end

        def add_learnosity_assets(assets, path, learnosity)
            process_assets!(
                assets,
                path,
                learnosity[:stimulus]
            )

            if learnosity[:image]
                process_image_asset!(assets, path, learnosity[:image])
            end

            learnosity
        end

        private

        def process_image_asset!(assets, path, image_hash)
            source = image_hash[:source]
            return unless source

            if /^\$IMS-CC-FILEBASE\$(.*)/.match(source)
                img_path = ''
                asset_path = $1
            elsif /^((?!https?:).*)/.match(source)
                img_path = path
                asset_path = $1
            else
                return
            end

            asset_path = asset_path.split("?").first.gsub(/^\//, '')
            asset_path = File.join(img_path, asset_path).gsub(/^\//, '')
            clean_ext = File.extname(asset_path).gsub(/[^a-z0-9_.-]/i, '')
            assets[asset_path] ||= "#{SecureRandom.uuid}#{clean_ext}"
            image_hash[:source] = "___EXPORT_ROOT___/assets/#{assets[asset_path]}"
        end
    end
end
