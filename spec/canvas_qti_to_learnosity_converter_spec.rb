RSpec.describe CanvasQtiToLearnosityConverter do
  describe "multiple choice" do
    it "handles a basic multiple choice question" do
      expected_result = CanvasQtiToLearnosityConverter.
        build_item_from_file(fixture_path("learnosity_multiple_choice.json"))
      qti_quiz = CanvasQtiToLearnosityConverter.
        build_quiz_from_file fixture_path("multiple_choice.qti.xml")
      result = CanvasQtiToLearnosityConverter.convert_item(qti_quiz, assets, 0)
      expect(result).to eql(expected_result)
    end
  end

  describe "True False" do
    it "handles a basic true false question" do
      expected_result = CanvasQtiToLearnosityConverter.
        build_item_from_file(fixture_path("learnosity_true_false.json"))
      qti_quiz = CanvasQtiToLearnosityConverter.
        build_quiz_from_file fixture_path("true_false.qti.xml")
      result = CanvasQtiToLearnosityConverter.convert_item(qti_quiz, {}, 0)
      expect(result).to eql(expected_result)
    end
  end

  describe "Multiple Answer" do
    it "handles a basic multiple answer question" do
      expected_result = CanvasQtiToLearnosityConverter.
        build_item_from_file(
          fixture_path("learnosity_multiple_answer.json"),
          CanvasQtiToLearnosityConverter::MultipleAnswersLearnosityQuestion,
       )
      qti_quiz = CanvasQtiToLearnosityConverter.
        build_quiz_from_file fixture_path("multiple_answer.qti.xml")
      result = CanvasQtiToLearnosityConverter.convert_item(qti_quiz, {}, 0)
      expect(result).to eql(expected_result)
    end
  end

  describe "Convert canvas quiz items" do
    it "handles qti strings" do
      qti_string = CanvasQtiToLearnosityConverter.
        read_file(fixture_path("all_question_types.qti.xml"))
      result = CanvasQtiToLearnosityConverter.convert(qti_string, {})

      expect(result[:title]).to eql("All Questions")
      expect(result[:ident]).to eql("i68e7925af6a9e291012ad7e532e56c0b")
      expect(result[:items].size).to eql 3
    end
  end

  describe "Imscc Export" do
    it "Converts imscc export package of quizzes" do
      result = CanvasQtiToLearnosityConverter.convert_imscc_export(fixture_path("imscc.zip"))

      expect(result[:assessments].size).to eql(1)
      expect(result[:assessments].first[:title]).to eql("All Questions")
    end
  end
end
