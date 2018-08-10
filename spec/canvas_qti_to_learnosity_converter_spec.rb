RSpec.describe CanvasQtiToLearnosityConverter do
  describe "multiple choice" do
    it "handles a basic multiple choice question" do
      qti_file = File.new("spec/fixtures/multiple_choice.qti.xml")
      qti = qti_file.read
      question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(learnosity[:type]).to eq "mcq"
      expect(learnosity[:stimulus]).to eq "<div><p>Test Multiple Choice, a is to?</p></div>"

      expect(learnosity[:options]).to eq [{
          "value" => "1487",
          "label" => "A"
      }, {
          "value" => "5358",
          "label" => "B"
      }, {
          "value" => "4197",
          "label" => "C"
      }, {
          "value" => "4598",
          "label" => "D"
      }]

      expect(learnosity[:validation]).to eq({
        "scoring_type" => "exactMatch",
        "valid_response" => {
          "value" => ["1487"],
        }
      })
    end
  end

  describe "True False" do
    it "handles a basic true false question" do
      qti_file = File.new("spec/fixtures/true_false.qti.xml")
      qti = qti_file.read
      question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(learnosity[:type]).to eq "mcq"
      expect(learnosity[:stimulus]).to eq "<div><p>The grand canyon is deep?</p></div>"

      expect(learnosity[:options]).to eq [
        {"value"=>"7161", "label"=>"True"},
        {"value"=>"460", "label"=>"False"},
      ]

      expect(learnosity[:validation]).to eq({
        "scoring_type" => "exactMatch",
        "valid_response" => { "value"=>["7161"] },
      })
    end
  end

  describe "Multiple Answer" do
    it "handles a basic multiple answer question" do
      qti_file = File.new("spec/fixtures/multiple_answer.qti.xml")
      qti = qti_file.read
      question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(learnosity[:type]).to eq "mcq"
      expect(learnosity[:stimulus]).to eq "<div><p>Which are prime?</p></div>"
      expect(learnosity[:options]).to eq [
        {"value"=>"945", "label"=>""},
        {"value"=>"6532", "label"=>""},
        {"value"=>"9078", "label"=>"3"},
        {"value"=>"5022", "label"=>"5"},
        {"value"=>"907", "label"=>"6"},
        {"value"=>"9720", "label"=>"7"},
      ]

      expect(learnosity[:validation]).to eq({
        "scoring_type"=>"partialMatch",
        "alt_responses"=>["9078", "5022", "9720"]
      })

      expect(learnosity[:multiple_responses]).to eq true
    end
  end

  describe "Matching" do
    it "handles a basic matching question" do
      qti_file = File.new("spec/fixtures/matching.qti.xml")
      qti = qti_file.read
      question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(learnosity[:type]).to eq "association"
      expect(learnosity[:stimulus]).to eq "<div><p>matching question</p></div>"
      expect(learnosity[:stimulus_list]).to eq([
        "left 1", "left 2", "left 3"
      ])

      expect(learnosity[:validation]).to eq({
        "scoring_type" => "partialMatch",
        "valid_response" => {
          "value" => ["right 1", "right 2", "right 3"],
        }
      })

      expect(learnosity[:possible_responses]).to eq([
        "right 1", "right 2", "right 3", "wrong 1", "wrong 2", "wrong 3"
      ])

      expect(learnosity[:duplicate_responses]).to eq(true)
    end
  end

  describe "Multiple Dropdowns" do
    it "handles a basic multiple dropdowns question" do
      qti_file = File.new("spec/fixtures/multiple_dropdowns.qti.xml")
      qti = qti_file.read
      question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(learnosity[:type]).to eq "clozedropdown"
      expect(learnosity[:stimulus]).to eq ""
      expect(learnosity[:template]).to eq "<div><p>multiple dropdowns {{response}} {{response}}</p></div>"
      expect(learnosity[:validation]).to eq({
        "scoring_type" => "partialMatch",
        "valid_response" => {
          "value" => ["right", "right"],
        }
      })

      expect(learnosity[:possible_responses]).to eq([
        ["right", "wrong"],
        ["right", "wrong"],
      ])
    end
  end

  describe "Short Answer" do
    it "handles a basic short answer question" do
      qti_file = File.new("spec/fixtures/short_answer.qti.xml")
      qti = qti_file.read
      question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(learnosity[:type]).to eq "shorttext"
      expect(learnosity[:stimulus]).to eq "<div><p>Fill in the</p></div>"
      expect(learnosity[:validation]).to eq({
        "scoring_type"=>"exactMatch",
        "valid_response"=>{"value"=>"Blank"},
        "alt_responses"=>[
          {"value"=>"blank"},
          {"value"=>"space"},
          {"value"=>"empty spot"},
        ]
      })
    end
  end

  describe "Essay Question" do
    it "handles a basic essay question" do
      qti_file = File.new("spec/fixtures/essay.qti.xml")
      qti = qti_file.read
      question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(learnosity[:type]).to eq "longtextV2"
      expect(learnosity[:stimulus]).to eq "<div><p>What do you think?</p></div>"
    end
  end

  describe "File Upload Question" do
    it "handles a basic file upload question" do
      qti_file = File.new("spec/fixtures/file_upload.qti.xml")
      qti = qti_file.read
      question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(learnosity[:type]).to eq "fileupload"
      expect(learnosity[:stimulus]).to eq "<div><p>Give me a good file.</p></div>"
    end
  end

  describe "Fill The Blanks Question" do
    it "handles a basic fill the blanks question" do
      qti_file = File.new("spec/fixtures/fill_blanks.qti.xml")
      qti = qti_file.read
      question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(learnosity[:type]).to eq "clozetext"
      expect(learnosity[:stimulus]).to eq ""
      expect(learnosity[:template]).to eq "<div><p>Roses are {{response}}, violets are {{response}}</p></div>"
      expect(learnosity[:validation]).to eq({
        "scoring_type" => "partialMatch",
        "valid_response" => {
          "value"=>["Red", "Blue"]
        },
        "alt_responses" => [
          {"value"=>["Red", "BLUE"]},
          {"value"=>["Red", "blue"]},
          {"value"=>["red", "Blue"]},
          {"value"=>["red", "BLUE"]},
          {"value"=>["red", "blue"]},
          {"value"=>["RED", "Blue"]},
          {"value"=>["RED", "BLUE"]},
          {"value"=>["RED", "blue"]},
        ]
      })
    end
  end

  describe "Numerical" do
    it "handles a basic numerical question" do
      qti_file = File.new("spec/fixtures/numerical.qti.xml")
      qti = qti_file.read
      question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(learnosity[:type]).to eq "formulaV2"
      expect(learnosity[:stimulus]).to eq "<div><p>Numerical answer (1, 2, 3 or 1.2 work)</p></div>"
      expect(learnosity[:validation]).to eq({
        "scoring_type"=>"exactMatch",
        "valid_response" => {
          "value" => [{"method"=>"equivValue", "value"=>"1.2\\pm0.05"}]
        },
        "alt_responses"=> [
          { "value"=>[{ "method"=> "equivValue", "value"=>"1.0\\pm0.1" }] },
          { "value"=>[{ "method"=> "equivValue", "value"=>"2.0\\pm0.1" }] },
          { "value"=>[{ "method"=> "equivValue", "value"=>"3.0\\pm0.1" }] },
          { "value"=>[{ "method"=> "equivValue", "value"=>"8.0\\pm3.0" }] },
        ]
      })
    end
  end

  describe "Convert canvas quiz items" do
    it "handles qti strings" do
      qti_string = CanvasQtiToLearnosityConverter.
        read_file(fixture_path("all_question_types.qti.xml"))
      result = CanvasQtiToLearnosityConverter.convert(qti_string, {})

      expect(result[:title]).to eql("All Questions")
      expect(result[:ident]).to eql("i68e7925af6a9e291012ad7e532e56c0b")
      expect(result[:items].size).to eql 10
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
