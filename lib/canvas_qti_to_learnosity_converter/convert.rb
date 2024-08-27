require "nokogiri"
require "forwardable"
require "ostruct"
require "zip"
require "uri"
require "active_support"
require "active_support/core_ext/digest/uuid"
require "active_support/core_ext/securerandom"
require "active_support/core_ext/object"

require "canvas_qti_to_learnosity_converter/export_writer"
require "canvas_qti_to_learnosity_converter/questions/multiple_choice"
require "canvas_qti_to_learnosity_converter/questions/short_answer"
require "canvas_qti_to_learnosity_converter/questions/fill_the_blanks"
require "canvas_qti_to_learnosity_converter/questions/multiple_dropdowns"
require "canvas_qti_to_learnosity_converter/questions/matching"
require "canvas_qti_to_learnosity_converter/questions/essay"
require "canvas_qti_to_learnosity_converter/questions/file_upload"
require "canvas_qti_to_learnosity_converter/questions/text_only"
require "canvas_qti_to_learnosity_converter/questions/numerical"
require "canvas_qti_to_learnosity_converter/questions/calculated"

module CanvasQtiToLearnosityConverter
  class Converter
    FEATURE_TYPES = [ :text_only_question ]
    QUESTION_TYPES = [
      :multiple_choice_question,
      :true_false_question,
      :multiple_answers_question,
      :short_answer_question,
      :fill_in_multiple_blanks_question,
      :multiple_dropdowns_question,
      :matching_question,
      :essay_question,
      :file_upload_question,
    ]

    TYPE_MAP = {
      multiple_choice_question: MultipleChoiceQuestion,
      true_false_question: MultipleChoiceQuestion,
      multiple_answers_question: MultipleAnswersQuestion,
      short_answer_question: ShortAnswerQuestion,
      fill_in_multiple_blanks_question: FillTheBlanksQuestion,
      multiple_dropdowns_question: MultipleDropdownsQuestion,
      matching_question: MatchingQuestion,
      essay_question: EssayQuestion,
      file_upload_question: FileUploadQuestion,
      text_only_question: TextOnlyQuestion,
      numerical_question: NumericalQuestion,
      calculated_question: CalculatedQuestion,

      "cc.multiple_choice.v0p1": MultipleChoiceQuestion,
      "cc.multiple_response.v0p1": MultipleAnswersQuestion,
      "cc.fib.v0p1": ShortAnswerQuestion,
      "cc.true_false.v0p1": MultipleChoiceQuestion,
      "cc.essay.v0p1": EssayQuestion,
    }

    attr_accessor :items, :widgets, :item_banks, :assessments, :assets, :errors

    def initialize
      @items = []
      @widgets = []
      @item_banks = []
      @assessments = []
      @assets = {}
      @errors = {}
      @namespace = SecureRandom.uuid
    end

    class CanvasQuestionTypeNotSupportedError < RuntimeError
      attr_reader :question_type
      def initialize(question_type)
        @question_type = question_type.to_s
        super("Unsupported question type #{@question_type}")
      end
    end

    class CanvasEntryTypeNotSupportedError < RuntimeError
      attr_reader :question_type
      def initialize(entry_type)
        @entry_type = entry_type.to_s
        super("Unsupported entry type #{@entry_type}")
      end
    end

    class CanvasQtiQuiz
      extend Forwardable
      def_delegators :@xml, :css, :at_css

      def initialize(qti_string:)
        @xml = Nokogiri.XML(qti_string, &:noblanks)
      end
    end

    def build_quiz_from_qti_string(qti_string)
      CanvasQtiQuiz.new(qti_string: qti_string)
    end

    def build_quiz_from_file(path)
      qti_file = File.new path
      qti_string = qti_file.read
      CanvasQtiQuiz.new(qti_string: qti_string)
    ensure
      qti_file.close
    end

    def extract_type(xml)
      xml.css(%{ item > itemmetadata > qtimetadata >
        qtimetadatafield > fieldlabel:contains("question_type")})
        &.first&.next&.text&.to_sym ||
        xml.css(%{ item > itemmetadata > qtimetadata >
          qtimetadatafield > fieldlabel:contains("cc_profile")})
          &.first&.next&.text&.to_sym
    end

    def convert_item(qti_string:)
      xml = Nokogiri.XML(qti_string, &:noblanks)
      type = extract_type(xml)

      if FEATURE_TYPES.include?(type)
        learnosity_type = "feature"
      else
        learnosity_type = "question"
      end

      question_class = TYPE_MAP[type]

      if question_class
        question = question_class.new(xml)
      else
        raise CanvasQuestionTypeNotSupportedError.new(type)
      end

      [learnosity_type, question]
    end

    def clean_title(title)
      title&.gsub(/["']/, "")
    end

    def convert_assessment(qti, path)
      quiz = CanvasQtiQuiz.new(qti_string: qti)
      assessment = quiz.at_css("assessment")
      return nil unless assessment

      ident = assessment.attribute("ident")&.value
      reference = build_reference(ident)
      title = clean_title(assessment.attribute("title").value)

      item_refs = convert_items(quiz, path)
      @assessments <<
        {
          reference:,
          title:,
          data: {
            items: item_refs.uniq.map { |ref| { reference: ref } },
            config: { title: },
          },
          status: "published",
          tags: {},
        }
    end

    def convert_item_bank(qti_string, path)
      qti = CanvasQtiQuiz.new(qti_string:)
      item_bank = qti.at_css("objectbank")
      return nil unless item_bank

      ident = item_bank.attribute("ident")&.value
      title = clean_title(qti.css(%{ objectbank > qtimetadata >
        qtimetadatafield > fieldlabel:contains("bank_title")})
        &.first&.next&.text || '')

      meta = {
        original_item_bank_ref: ident,
      }
      item_refs = convert_items(qti, path, meta:, tags: { "Item Bank" => [title] })
      @item_banks <<
        {
          title: title,
          ident: ident,
          item_refs: item_refs,
        }
    end

    def build_reference(ident = nil)
      if ident.present?
        Digest::UUID.uuid_v5(@namespace, ident)
      else
        SecureRandom.uuid
      end
    end

    def convert_items(qti, path, meta: {}, tags: {})
      converted_item_refs = []
      qti.css("item,bankentry_item,section").each.with_index do |item, index|
        begin
          ident = item.attribute("ident")&.value
          if item.name == "section"
            next if ident == "root_section"

            item.css("sourcebank_ref").each do |sourcebank_ref|
              item_refs = @items.select { |i| i.dig(:metadata, :original_item_bank_ref) == sourcebank_ref.text }.map { |i| i[:reference] }
              converted_item_refs += item_refs
            end
          elsif item.name == "bankentry_item"
            item_ref = item.attribute("item_ref")&.value
            if item_ref
              converted_item_refs.push(build_reference(item_ref))
            end
          elsif item.name == "item"
            reference = build_reference(ident)
            item_title = item.attribute("title")&.value || ''
            learnosity_type, quiz_item = convert_item(qti_string: item.to_html)

            item_widgets = [
              {
                type: learnosity_type,
                data: quiz_item.convert(@assets, path),
                reference: build_reference,
              }
            ]
            @widgets += item_widgets

            @items << {
              title: item_title,
              reference:,
              metadata: meta.merge({ original_item_ref: ident }),
              definition: {
                widgets: item_widgets.map{ |w| { reference: w[:reference] } },
              },
              questions: item_widgets.select{ |w| w[:type] == "question" }.map{ |w| w[:reference] },
              features: item_widgets.select{ |w| w[:type] == "feature" }.map{ |w| w[:reference] },
              status: "published",
              tags: tags,
              type: learnosity_type,
              dynamic_content_data: quiz_item.dynamic_content_data()
            }

            converted_item_refs.push(reference)
          end

        rescue CanvasQuestionTypeNotSupportedError => e
          @errors[ident] ||= []
          @errors[ident].push({
            index: index,
            error_type: "unsupported_question",
            question_type: e.question_type.to_s,
            message: e.message,
          })
        rescue StandardError => e
          @errors[ident] ||= []
          @errors[ident].push({
            index: index,
            error_type: e.class.to_s,
            message: e.message,
          })
        end
      end
      converted_item_refs
    end

    def convert_qti_file(path)
      file = File.new(path)
      qti_string = file.read
      convert(qti_string)
    ensure
      file.close
      file.unlink
    end

    def imscc_quiz_paths(parsed_manifest)
      resources = parsed_manifest.css("resources > resource[type^='imsqti_xmlv1p2']")
      resources.map do |entry|
        resource_path(parsed_manifest, entry)
      end
    end

    def imscc_item_bank_paths(parsed_manifest)
      resources = parsed_manifest.css("resources > resource[type='associatedcontent/imscc_xmlv1p1/learning-application-resource']")
      resources.map do |entry|
        resource_path(parsed_manifest, entry)
      end
    end

    def resource_path(parsed_manifest, entry)
      # Use the Canvas non_cc_assignment qti path when possible.  This works for both classic and new quizzes
      entry.css("dependency").each do |dependency|
        ref = dependency.attribute("identifierref").value
        parsed_manifest.css(%{resources > resource[identifier="#{ref}"] > file}).each do |file|
          path = file.attribute("href").value
          return path if path.match?(/^non_cc_assessments/)
        end
      end
      entry.css("file").first&.attribute("href")&.value
    end

    def convert_imscc_export(path)
      Zip::File.open(path) do |zip_file|
        entry = zip_file.find_entry("imsmanifest.xml")
        manifest = entry.get_input_stream.read
        parsed_manifest = Nokogiri.XML(manifest, &:noblanks)

        item_bank_paths = imscc_item_bank_paths(parsed_manifest)
        item_bank_paths.each do |item_bank_path|
          qti = zip_file.find_entry(item_bank_path).get_input_stream.read
          convert_item_bank(qti, File.dirname(item_bank_path))
        end

        assessment_paths = imscc_quiz_paths(parsed_manifest)
        assessment_paths.each do |qti_path|
          qti = zip_file.find_entry(qti_path).get_input_stream.read
          convert_assessment(qti, File.dirname(qti_path))
        end

        {
          errors: @errors,
        }
      end
    end

    def generate_learnosity_export(input_path, output_path)
      result = convert_imscc_export(input_path)

      export_writer = ExportWriter.new(output_path)
      export_writer.write_to_zip("export.json", { version: 2.0 })

      @assessments.each do |activity|
        export_writer.write_to_zip("activities/#{activity[:reference]}.json", activity)
      end
      @items.each do |item|
        export_writer.write_to_zip("items/#{item[:reference]}.json", item)
      end
      @widgets.each do |widget|
        export_writer.write_to_zip("#{widget[:type]}s/#{widget[:reference]}.json", widget)
      end

      Zip::File.open(input_path) do |input|
        @assets.each do |source, destination|
          source = source.gsub(/^\//, '')
          asset = input.find_entry(source) || input.find_entry("web_resources/#{source}")
          if asset
            export_writer.write_asset_to_zip("assets/#{destination}", input.read(asset))
          end
        end
      end
      export_writer.close

      result
    end
  end
end
