RSpec.describe CanvasQtiToLearnosityConverter do
  describe "multiple choice" do
    it "handles a basic multiple choice question" do
      expected_result = CanvasQtiToLearnosityConverter.
        build_item_from_file(fixture_path("learnosity_multiple_choice.json"))
      qti_quiz = CanvasQtiToLearnosityConverter.
        build_quiz_from_file fixture_path("multiple_choice.qti.xml")
      result = CanvasQtiToLearnosityConverter.convert_item(qti_quiz)
      expect(result).to eql(expected_result)
    end
  end

  describe "True False" do
    it "handles a basic true false question" do
      expected_result = CanvasQtiToLearnosityConverter.
        build_item_from_file(fixture_path("learnosity_true_false.json"))
      qti_quiz = CanvasQtiToLearnosityConverter.
        build_quiz_from_file fixture_path("true_false.qti.xml")
      result = CanvasQtiToLearnosityConverter.convert_item(qti_quiz)
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
      result = CanvasQtiToLearnosityConverter.convert_item(qti_quiz)
      expect(result).to eql(expected_result)
    end
  end

end
