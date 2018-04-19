require "nokogiri"
require "forwardable"
require "ostruct"

module CanvasQtiToLearnosityConverter
  class CanvasQuestionTypeNotSupportedError < RuntimeError
  end

  class CanvasQtiQuiz
    extend Forwardable
    def_delegators :@xml, :css

    attr_reader :xml
    def initialize(qti_string:)
      @xml = Nokogiri.XML(qti_string, &:noblanks)
    end
  end

  class LearnosityQuestion < OpenStruct
  end

  class MultipleChoiceLearnosityQuestion < LearnosityQuestion
  end

  class Learnosityitem
  end

  class LearnosityActivity
  end

  LEARNOSITY_TYPE_MAP = {
    "mcq" => MultipleChoiceLearnosityQuestion
  }

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

  def self.build_item_from_file(path)
    file = File.new path
    file_val = JSON.parse(file.read)
    type = file_val["type"]
    return LearnosityQuestion.new(file_val) if type.nil?
    LEARNOSITY_TYPE_MAP[type].new(file_val)
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

   def self.convert_item(qti_quiz)
    type = extract_type(qti_quiz)
    case type
    when :multiple_choice_question
      convert_multiple_choice(qti_quiz)
    else
      raise CanvasQuestionTypeNotSupportedError
    end
  end

  def self.convert(qti)
    nil
  end

end
