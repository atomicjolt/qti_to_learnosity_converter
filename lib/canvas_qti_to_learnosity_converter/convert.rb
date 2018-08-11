require "nokogiri"
require "forwardable"
require "ostruct"
require "zip"
require "uri"

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
  }

  class CanvasQuestionTypeNotSupportedError < RuntimeError
  end

  class CanvasQtiQuiz
    extend Forwardable
    def_delegators :@xml, :css

    def initialize(qti_string:)
      @xml = Nokogiri.XML(qti_string, &:noblanks)
    end
  end


  def self.read_file(path)
    file = File.new path
    file.read
  ensure
    file.close
  # Do we need to unlink?
  end

  def self.build_quiz_from_qti_string(qti_string)
    CanvasQtiQuiz.new(qti_string: qti_string)
  end

  def self.build_quiz_from_file(path)
    qti_file = File.new path
    qti_string = qti_file.read
    CanvasQtiQuiz.new(qti_string: qti_string)
  ensure
    qti_file.close
  end

  def self.add_files_to_assets(assets, path, text)
    text.scan(/%24IMS-CC-FILEBASE%24\/([^"]+)/).flatten.each do |asset_path|
      decoded_path = URI.unescape(asset_path)
      assets[decoded_path] ||= []
      assets[decoded_path].push(path)
    end
  end

  def self.extract_type(xml)
    xml.css(%{ item > itemmetadata > qtimetadata >
      qtimetadatafield > fieldlabel:contains("question_type")})
      &.first&.next&.text&.to_sym
  end

  def self.convert_item(qti_string:)
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
      raise CanvasQuestionTypeNotSupportedError
    end

    [learnosity_type, question]
  end

  def self.clean_title(title)
    title.gsub(/["']/, "")
  end

  def self.convert(qti, assets)
    quiz = CanvasQtiQuiz.new(qti_string: qti)
    assessment = quiz.css("assessment")
    ident = assessment.attribute("ident").value
    assets[ident] = {}

    items = []

    quiz.css("item").each.with_index do |item, index|
      begin
        learnosity_type, quiz_item = convert_item(qti_string: item.to_html)

        item = {
          type: learnosity_type,
          data: quiz_item.to_learnosity,
          dynamic_content_data: quiz_item.dynamic_content_data()
        }

        items.push(item)
        path = [items.count - 1, :data]

        quiz_item.add_learnosity_assets(assets[ident], path)
      rescue CanvasQuestionTypeNotSupportedError
        nil
      end
    end

    {
      title: clean_title(assessment.attribute("title").value),
      ident: ident,
      items: items,
    }
  end

  def self.convert_qti_file(path)
    file = File.new(path)
    qti_string = file.read
    convert(qti_string)
  ensure
    file.close
    file.unlink
  end

  def self.imscc_quiz_paths(parsed_manifest)
    parsed_manifest.css("resources > resource[type='imsqti_xmlv1p2'] > file").
      map { |entry| entry.attribute("href").value }
  end

  def self.convert_imscc_export(path)
    Zip::File.open(path) do |zip_file|
      entry = zip_file.find_entry("imsmanifest.xml")
      manifest = entry.get_input_stream.read
      parsed_manifest = Nokogiri.XML(manifest, &:noblanks)
      paths = imscc_quiz_paths(parsed_manifest)

      assets = {}
      converted_assesments = paths.map do |qti_path|
        qti = zip_file.find_entry(qti_path).get_input_stream.read
        convert(qti, assets)
      end

      {
        assessments: converted_assesments,
        assets: assets,
      }
    end
  end
end
