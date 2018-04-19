require 'nokogiri'

module CanvasQtiToLearnosityConverter
  class CanvasQuestionTypeNotSupportedError < RuntimeError
  end

  class CanvasQtiQuiz
    def initialize(qti_string:)
      @xml = Nokogiri.XML(qti_string)
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
    result = qti_quiz.xpath('item > itemmetadata > qtimetadata > qtimetadatafield')
    byebug
    result
#    return item
#       .find('item > itemmetadata > qtimetadata > qtimetadatafield > fieldlabel:contains("question_type")')
#       .next().text();
  end

   def self.convert_multiple_choice(qti_quiz)
   end

   def self.convert_item(qti_quiz)
#     const type = extractType($, item);
#
#     switch (type) {
#       case 'multiple_choice_question': { return convertMultipleChoice($, item); }
#       case 'true_false_question': { return convertTrueFalse($, item); }
#       case 'multiple_answers_question': { return convertMultipleAnswer($, item); }
#       default: {
#--       console.error('QTI question type not supported');
#       }
#     }
    type = extract_type(qti_quiz)
    case type
    when :multiple_choice
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
