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

module CanvasQtiToLearnosityConverter
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

    case type
    when :multiple_choice_question
      MultipleChoiceQuestion.new(xml)
    when :true_false_question
      MultipleChoiceQuestion.new(xml)
    when :multiple_answers_question
      MultipleAnswersQuestion.new(xml)
    when :short_answer_question
      ShortAnswerQuestion.new(xml)
    when :fill_in_multiple_blanks_question
      FillTheBlanksQuestion.new(xml)
    when :multiple_dropdowns_question
      MultipleDropdownsQuestion.new(xml)
    when :matching_question
      MatchingQuestion.new(xml)
    when :essay_question
      EssayQuestion.new(xml)
    when :file_upload_question
      FileUploadQuestion.new(xml)
    else
      raise CanvasQuestionTypeNotSupportedError
    end
  end

  def self.convert(qti, assets)
    quiz = CanvasQtiQuiz.new(qti_string: qti)
    assessment = quiz.css("assessment")
    ident = assessment.attribute("ident").value
    assets[ident] = {}

    items = quiz.css("item").map.with_index do |item, index|
      begin
        quiz_item = convert_item(qti_string: item.to_html)
        quiz_item.add_learnosity_assets(assets[ident], [index])
        quiz_item.to_learnosity()
      rescue CanvasQuestionTypeNotSupportedError
        nil
      rescue StandardError => e
        puts e.message
        puts e.backtrace
      end
    end.compact

    {
      title: assessment.attribute("title").value,
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
