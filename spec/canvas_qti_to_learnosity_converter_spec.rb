RSpec.describe CanvasQtiToLearnosityConverter do
  describe "multiple choice" do
    it "handles a basic multiple choice question" do
      expected_result = JSON.parse(read_fixture('learnosity_multiple_choice.json'))
      qti_quiz = CanvasQtiToLearnosityConverter
                 .build_quiz_from_file fixture_path('multiple_choice.qti.xml')
      result = CanvasQtiToLearnosityConverter.convert_item(qti_quiz)
      expect(expected_result).to equal(result)
    end
  end

#  describe 'True False' do
#    it 'handles a basic true false question' do
#      expected_result = JSON.parse(fixture('learnosity_true_false.json'))
#      qti = read_fixture('true_false.qti.xml')
#      result = CanvasQtiToLearnosityConverter.convert_item(qti)
#      expect(expected_result).to equal(result)
#    end
#  end
end
