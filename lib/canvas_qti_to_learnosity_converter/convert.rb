require "nokogiri"
require "forwardable"
require "ostruct"
require "zip"
require "uri"

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

    def self.extract_mattext(mattext_node)
      mattext_node.content
    end

    def extract_type()
      @xml.css(%{ item > itemmetadata > qtimetadata >
        qtimetadatafield > fieldlabel:contains("question_type")})
        &.first&.next&.text&.to_sym
    end

    def extract_multiple_choice_options()
      choices = @xml.css("item > presentation > response_lid > render_choice > response_label")
      choices.map do |choice|
        ident = choice.attribute("ident").value
        {
          "value" => ident,
          "label" => self.class.extract_mattext(choice.css("material > mattext").first),
        }
      end
    end

    def extract_multiple_choice_validation()
      resp_conditions = @xml.css("item > resprocessing > respcondition")
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

    def extract_stimulus()
      mattext = @xml.css("item > presentation > material > mattext").first
      self.class.extract_mattext(mattext)
    end

    def extract_lid_response_id()
      @xml.css("item > presentation > response_lid").attribute("ident").value
    end

    def extract_str_response_id()
      @xml.css("item > presentation > response_str").attribute("ident").value
    end

    def extract_multiple_answers_validation()
      correct_condition = @xml.css('item > resprocessing > respcondition[continue="No"] > conditionvar > and > varequal')
      alt_responses = correct_condition.map(&:text)
      {
        "scoring_type" => "partialMatch",
        "alt_responses" => alt_responses,
      }
    end

    def extract_short_text_validation()
      correct_responses = @xml.css('item > resprocessing >
        respcondition[continue="No"] > conditionvar > varequal')
      correct_response = { "value" => correct_responses.shift.text }
      {
        "scoring_type" => "exactMatch",
        "valid_response" => correct_response,
        "alt_responses" => correct_responses.map { |res| { "value" => res.text } }
      }
    end

    def extract_fitb_template()
      blanks = @xml.css("item > presentation > response_lid > material >
        mattext").map { |text| self.class.extract_mattext(text) }

      template_node_list = @xml.css("item > presentation > material > mattext")
      template = self.class.extract_mattext(template_node_list.first)

      blanks.each do |blank|
        template.sub!("[#{blank}]", "{{response}}")
      end

      template
    end

    def extract_fitb_validation()
      template_node_list = @xml.css("item > presentation > material > mattext")
      template = self.class.extract_mattext(template_node_list.first)

      responses = template.scan(/\[([^\]]+)\]/).map do |blank_name|
        name = blank_name.first
        result = @xml.css(%{item > presentation >
          response_lid[ident="response_#{name}"] > render_choice material >
          mattext}).map do |node|
          self.class.extract_mattext(node)
        end

        if result.empty?
          nil
        else
          result
        end
      end.compact

      all_responses = []
      create_responses(responses, 0, all_responses, [])

      {
        "scoring_type" => "exactMatch",
        "valid_response" => all_responses.shift,
        "alt_responses" => all_responses
      }
    end

    def create_responses(blank_responses, depth, result, current_response)
      if depth == blank_responses.count
        result.push({ "value" => current_response })
        return
      end

      blank_responses[depth].each do |possible_response|
        create_responses(blank_responses, depth + 1, result, current_response + [possible_response])
      end
    end

    def convert(assets, path)
      type = extract_type()

      question = case type
      when :multiple_choice_question
        MultipleChoiceLearnosityQuestion.from_qti(self, assets, path)
      when :true_false_question
        MultipleChoiceLearnosityQuestion.from_qti(self, assets, path)
      when :multiple_answers_question
        MultipleAnswersLearnosityQuestion.from_qti(self, assets, path)
      when :short_answer_question
        ShortTextLearnosityQuestion.from_qti(self, assets, path)
      when :fill_in_multiple_blanks_question
        FillInTheBlanksLearnosityQuestion.from_qti(self, assets, path)
  #    when :multiple_dropdowns_question
  #      convert_multiple_dropdowns(qti_quiz)
  #    when :matching_question
  #      convert_matching(qti_quiz)
  #    when :numerical_question
  #      convert_numerical(qti_quiz)
  #    when :essay_question
  #      convert_essay(qti_quiz)
  #    when :file_upload_question
  #      convert_file_upload(qti_quiz)
  #    when :text_only_question
  #      convert_text_only(qti_quiz)
      else
        raise CanvasQuestionTypeNotSupportedError
      end

      question.add_assets(assets, path)

      question
    end
  end

  class LearnosityQuestion < OpenStruct
    def add_assets(assets, path)
      CanvasQtiToLearnosityConverter.add_files_to_assets(
        assets,
        path + [:stimulus],
        self.stimulus
      )
    end
  end

  class MultipleChoiceLearnosityQuestion < LearnosityQuestion
    def self.from_qti(item, assets, path)
      MultipleChoiceLearnosityQuestion.new({
        stimulus: item.extract_stimulus(),
        options: item.extract_multiple_choice_options(),
        multiple_responses: false,
        response_id: item.extract_lid_response_id(),
        type: "mcq",
        validation: item.extract_multiple_choice_validation(),
      })
    end

    def add_assets(assets, path)
      CanvasQtiToLearnosityConverter.add_files_to_assets(
        assets,
        path + [:stimulus],
        self.stimulus
      )

      self.options.each.with_index do |option, index|
        CanvasQtiToLearnosityConverter.add_files_to_assets(
          assets,
          path + [:options, index, "label"],
          option["label"]
        )
      end
    end
  end

  class MultipleAnswersLearnosityQuestion < MultipleChoiceLearnosityQuestion
    def self.from_qti(item, assets, path)
      MultipleAnswersLearnosityQuestion.new({
        stimulus: item.extract_stimulus(),
        options: item.extract_multiple_choice_options(),
        multiple_responses: true,
        response_id: item.extract_lid_response_id(),
        type: "mcq",
        validation: item.extract_multiple_answers_validation(),
      })
    end
  end

  # This is fill in the blank in the Canvas UI, but it is actually a short
  # answer type.
  class ShortTextLearnosityQuestion < LearnosityQuestion
    def self.from_qti(item, assets, path)
      ShortTextLearnosityQuestion.new({
        type: "shorttext",
        stimulus: item.extract_stimulus(),
        validation: item.extract_short_text_validation(),
        response_id: item.extract_str_response_id(),
      })
    end
  end

  class FillInTheBlanksLearnosityQuestion < LearnosityQuestion
    def self.from_qti(item, assets, path)
      FillInTheBlanksLearnosityQuestion.new({
        type: "clozetext",
        stimulus: "",
        template: item.extract_fitb_template(),
        validation: item.extract_fitb_validation(),
      })
    end

    def add_assets(assets, path)
      CanvasQtiToLearnosityConverter.add_files_to_assets(
        assets,
        path + [:template],
        self.template
      )
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

  def self.convert(qti, assets)
    quiz = CanvasQtiQuiz.new(qti_string: qti)
    assessment = quiz.css("assessment")
    ident = assessment.attribute("ident").value
    assets[ident] = {}

    items = quiz.css("item").map.with_index do |item, index|
      begin
        quiz_item = CanvasQtiQuizQuestion.new(qti_string: item.to_html)
        quiz_item.convert(assets[ident], [index])
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

  def self.to_native_types(activity)
    clone = activity.clone
    clone[:items] = activity[:items].map(&:to_h)
    clone
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
        to_native_types(convert(qti, assets))
      end

      {
        assessments: converted_assesments,
        assets: assets,
      }
    end
  end
end
