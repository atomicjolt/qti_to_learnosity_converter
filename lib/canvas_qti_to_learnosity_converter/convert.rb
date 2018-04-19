require 'nokogiri'
require 'forwardable'

module CanvasQtiToLearnosityConverter
  class CanvasQuestionTypeNotSupportedError < RuntimeError
  end

  class CanvasQtiQuiz
    extend Forwardable
    def_delegators :@xml, :css

    attr_reader :xml
    def initialize(qti_string:)
      @xml = Nokogiri.XML(qti_string) { |config| config.noblanks }
    end
  end

  #  export function convert(qti) {
  #    const $ = cheerio.load(qti);
  #    const items = [];
  #    $('item').toArray().forEach((item) => {
  #      const convertedItem = convertItem($, $(item));
  #      if (!_.isNil(convertedItem)) { items.push(convertedItem); }
  #    });
  # 
  #    const title = $('questestinterop > assessment').attr('title');
  #    const ident = $('questestinterop > assessment').attr('ident');
  #    return {
  #      title,
  #      ident,
  #      items
  #    };

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

  def self.extract_type(qti_quiz)
    qti_quiz.css(%{ item > itemmetadata > qtimetadata >
      qtimetadatafield > fieldlabel:contains("question_type")})
      &.first&.next&.text&.to_sym
  end

   def self.convert_multiple_choice(qti_quiz)
# export function convertMultipleChoice($, item) {
#   const result = {
#     stimulus: extractStimulus($, item),
#     options: extractOptions($, item),
#     multiple_responses: false,
#     response_id: extractResponseId($, item),
#     type: 'mcq',
#     validation: extractMCValidation($, item),
#   };
# 
#   return result;
# }

   end

   def self.convert_item(qti_quiz)
    type = extract_type(qti_quiz)
    case type
    when :multiple_choice_question
      convert_multiple_choice(qti_quiz)
    else
      raise CanvasQuestionTypeNotSupportedError
    end
    nil
  end

  def self.convert(qti)
    nil
  end

end
