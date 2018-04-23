require "nokogiri"
require "forwardable"
require "ostruct"
require "zip"

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

  class CanvasQtiQuizQuestion
    extend Forwardable
    def_delegators :@xml, :css

    def initialize(qti_string:)
      @xml = Nokogiri.XML(qti_string, &:noblanks)
    end
  end

  class LearnosityQuestion < OpenStruct
  end

  class MultipleChoiceLearnosityQuestion < LearnosityQuestion
  end

  class MultipleAnswersLearnosityQuestion < LearnosityQuestion
  end

  class Learnosityitem
  end

  class LearnosityActivity
  end

  LEARNOSITY_TYPE_MAP = {
    "mcq" => MultipleChoiceLearnosityQuestion
  }

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

  def self.build_item_from_file(path, item_type = nil)
    file = File.new path
    file_val = JSON.parse(file.read)
    type = item_type || LEARNOSITY_TYPE_MAP[file_val["type"]]
    type.new(file_val)
  ensure
    file.close
  end

  def self.extract_type(item)
    item.css(%{ item > itemmetadata > qtimetadata >
      qtimetadatafield > fieldlabel:contains("question_type")})
      &.first&.next&.text&.to_sym
  end

  def self.extract_mattext(mattext_node)
    mattext_node.content
  end

  def self.extract_stimulus(item)
    mattext = item.css("item > presentation > material > mattext").first
    extract_mattext(mattext)
  end

  def self.extract_multiple_choice_options(item)
    choices = item.css("item > presentation > response_lid > render_choice > response_label")
    choices.map do |choice|
      ident = choice.attribute("ident").value
      {
        "value" => ident,
        "label" => extract_mattext(choice.css("material > mattext").first),
      }
    end
  end

  def self.extract_response_id(item)
    item.css("item > presentation > response_lid").attribute("ident").value
  end

  def self.extract_multiple_choice_validation(item)
    resp_conditions = item.css("item > resprocessing > respcondition")
    correct_condition = resp_conditions.select do |condition|
      setvar = condition.css("setvar")
      setvar.length === 1 && setvar.text === "100"
    end.first


    # TODO check for more than 1 element
    correct_value = correct_condition.css("varequal").text
    {
      "scoring_type" => "exactMatch",
      "valid_response" => {
        "value" => [correct_value],
      },
    }
  end

  def self.extract_multiple_answers_validation(item)
    correct_condition = item.css('item > resprocessing > respcondition[continue="No"] > conditionvar > and > varequal')
    alt_responses = correct_condition.map(&:text)
    {
      "scoring_type" => "partialMatch",
      "alt_responses" => alt_responses,
    }
  end

  def self.convert_multiple_choice(item)
    MultipleChoiceLearnosityQuestion.new({
      stimulus: extract_stimulus(item),
      options: extract_multiple_choice_options(item),
      multiple_responses: false,
      response_id: extract_response_id(item),
      type: "mcq",
      validation: extract_multiple_choice_validation(item),
    })
  end

  def self.convert_multiple_answers(item)
    MultipleAnswersLearnosityQuestion.new({
      stimulus: extract_stimulus(item),
      options: extract_multiple_choice_options(item),
      multiple_responses: true,
      response_id: extract_response_id(item),
      type: "mcq",
      validation: extract_multiple_answers_validation(item),
    })
   end

   def self.convert_item(qti_quiz)
     type = extract_type(qti_quiz)
     case type
     when :multiple_choice_question
       convert_multiple_choice(qti_quiz)
     when :true_false_question
       convert_multiple_choice(qti_quiz)
     when :multiple_answers_question
       convert_multiple_answers(qti_quiz)
     else
       raise CanvasQuestionTypeNotSupportedError
     end
  end

  def self.convert(qti)
    quiz = CanvasQtiQuiz.new(qti_string: qti)
    items = quiz.css("item").map do |item|
      begin
        quiz_item = CanvasQtiQuizQuestion.new(qti_string: item.to_html)
        convert_item(quiz_item)
      rescue CanvasQuestionTypeNotSupportedError
        nil
      end
    end.compact

    assessment = quiz.css("assessment")
    {
      title: assessment.attribute("title").value,
      ident: assessment.attribute("ident").value,
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
    # Find all quiz files
    # Convert for each file
     Zip::File.open(path) do |zip_file|
       entry = zip_file.find_entry("imsmanifest.xml")
       manifest = entry.get_input_stream.read
       parsed_manifest = Nokogiri.XML(manifest, &:noblanks)
       paths = imscc_quiz_paths(parsed_manifest)
       result = paths.map do |qti_path|
         qti = zip_file.find_entry(qti_path).get_input_stream.read
         convert(qti)
       end
       result
      end
  end
end
