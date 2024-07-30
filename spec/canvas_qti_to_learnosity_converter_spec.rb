RSpec.describe CanvasQtiToLearnosityConverter do
  describe "multiple choice" do
    it "handles a basic multiple choice question" do
      qti_file = File.new("spec/fixtures/multiple_choice.qti.xml")
      qti = qti_file.read
      question_type, question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(question_type).to eq "question"
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
          "score" => 3.0,
        }
      })
    end
  end

  describe "assets" do
    it "detects assets" do
      qti_file = File.new("spec/fixtures/assets.qti.xml")
      qti = qti_file.read
      question_type, question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)
      assets = {}
      question.add_learnosity_assets(assets, [:asset_path])

      expect(assets).to eq({
        "Uploaded Media/apple-1.jpeg" => [[:asset_path, :stimulus]],
        "Uploaded Media/apple-2.jpeg" => [[:asset_path, :stimulus]],
      })
    end
    it "detects newer style assets" do
      qti_file = File.new("spec/fixtures/assets_new_style.qti.xml")
      qti = qti_file.read
      question_type, question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)
      assets = {}
      question.add_learnosity_assets(assets, [:asset_path])

      expect(assets).to eq({
        "Uploaded Media/apple-1.jpeg" => [[:asset_path, :stimulus]],
        "Uploaded Media/apple-2.jpeg" => [[:asset_path, :stimulus]],
      })

    end
  end

  describe "True False" do
    it "handles a basic true false question" do
      qti_file = File.new("spec/fixtures/true_false.qti.xml")
      qti = qti_file.read
      question_type, question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(question_type).to eq "question"
      expect(learnosity[:type]).to eq "mcq"
      expect(learnosity[:stimulus]).to eq "<div><p>The grand canyon is deep?</p></div>"

      expect(learnosity[:options]).to eq [
        {"value"=>"7161", "label"=>"True"},
        {"value"=>"460", "label"=>"False"},
      ]

      expect(learnosity[:validation]).to eq({
        "scoring_type" => "exactMatch",
        "valid_response" => { "value"=>["7161"], "score"=>3.0 },
      })
    end
  end

  describe "Multiple Answer" do
    it "handles a basic multiple answer question" do
      qti_file = File.new("spec/fixtures/multiple_answer.qti.xml")
      qti = qti_file.read
      question_type, question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

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
        "scoring_type"=>"partialMatchV2",
        "rounding"=>"none",
        "penalty"=>3,
        "valid_response"=>{
          "score"=>3.0,
          "value"=>["9078", "5022", "9720"],
        },
      })

      expect(learnosity[:multiple_responses]).to eq true
    end
  end

  describe "Matching" do
    it "handles a basic matching question" do
      qti_file = File.new("spec/fixtures/matching.qti.xml")
      qti = qti_file.read
      question_type, question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(question_type).to eq "question"
      expect(learnosity[:type]).to eq "clozedropdown"
      expect(learnosity[:stimulus]).to eq "<div><p>matching question</p></div>"
      expect(learnosity[:template]).to eq("<p>left 1 {{response}}</p>\n<p>left 2 {{response}}</p>\n<p>left 3 {{response}}</p>")

      expect(learnosity[:validation]).to eq({
         "rounding"=>"none",
         "scoring_type"=>"partialMatchV2",
         "valid_response"=>{"score"=>3.0, "value"=>["right 1", "right 2", "right 3"]}
      })

      possible_responses = ["right 1", "right 2", "right 3", "wrong 1", "wrong 2", "wrong 3"]
      expect(learnosity[:possible_responses]).to eq([
        possible_responses, possible_responses, possible_responses,
      ])

      expect(learnosity[:duplicate_responses]).to eq(true)
    end
  end

  describe "Multiple Dropdowns" do
    it "handles a basic multiple dropdowns question" do
      qti_file = File.new("spec/fixtures/multiple_dropdowns.qti.xml")
      qti = qti_file.read
      question_type, question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(learnosity[:type]).to eq "clozedropdown"
      expect(learnosity[:stimulus]).to eq ""
      expect(learnosity[:template]).to eq "<div><p>multiple dropdowns {{response}} {{response}}</p></div>"
      expect(learnosity[:validation]).to eq({
        "scoring_type" => "partialMatchV2",
        "rounding" => "none",
        "valid_response" => {
          "score" => 3.0,
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
      question_type, question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(question_type).to eq "question"
      expect(learnosity[:type]).to eq "shorttext"
      expect(learnosity[:stimulus]).to eq "<div><p>Fill in the</p></div>"
      expect(learnosity[:validation]).to eq({
        "scoring_type"=>"exactMatch",
        "valid_response"=>{"value"=>"Blank", "score"=>2.0},
        "alt_responses"=>[
          {"value"=>"blank", "score"=>2.0},
          {"value"=>"space", "score"=>2.0},
          {"value"=>"empty spot", "score"=>2.0},
        ]
      })
    end
  end

  describe "Essay Question" do
    it "handles a basic essay question" do
      qti_file = File.new("spec/fixtures/essay.qti.xml")
      qti = qti_file.read
      question_type, question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(question_type).to eq "question"
      expect(learnosity[:type]).to eq "longtextV2"
      expect(learnosity[:stimulus]).to eq "<div><p>What do you think?</p></div>"
    end
  end

  describe "File Upload Question" do
    it "handles a basic file upload question" do
      qti_file = File.new("spec/fixtures/file_upload.qti.xml")
      qti = qti_file.read
      question_type, question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(question_type).to eq "question"
      expect(learnosity[:type]).to eq "fileupload"
      expect(learnosity[:stimulus]).to eq "<div><p>Give me a good file.</p></div>"
    end
  end

  describe "Fill The Blanks Question" do
    it "handles a basic fill the blanks question" do
      qti_file = File.new("spec/fixtures/fill_blanks.qti.xml")
      qti = qti_file.read
      question_type, question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(question_type).to eq "question"
      expect(learnosity[:type]).to eq "clozetext"
      expect(learnosity[:stimulus]).to eq ""
      expect(learnosity[:template]).to eq "<div><p>Roses are {{response}}, violets are {{response}}</p></div>"
      expect(learnosity[:validation]).to eq({
        "scoring_type" => "partialMatchV2",
        "rounding" => "none",
        "valid_response" => {
          "value"=>["Red", "Blue"],
          "score"=>2.0,
        },
        "alt_responses" => [
          {"value"=>["Red", "BLUE"], "score"=>2.0},
          {"value"=>["Red", "blue"], "score"=>2.0},
          {"value"=>["red", "Blue"], "score"=>2.0},
          {"value"=>["red", "BLUE"], "score"=>2.0},
          {"value"=>["red", "blue"], "score"=>2.0},
          {"value"=>["RED", "Blue"], "score"=>2.0},
          {"value"=>["RED", "BLUE"], "score"=>2.0},
          {"value"=>["RED", "blue"], "score"=>2.0},
        ]
      })
    end
  end

  describe "Text Only Question" do
    it "handles a basic text only question" do
      qti_file = File.new("spec/fixtures/text_only.qti.xml")
      qti = qti_file.read
      question_type, question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(question_type).to eq "feature"
      expect(learnosity[:type]).to eq "sharedpassage"
      expect(learnosity[:content]).to eq "<div><p>This is text. Do with it what you will.</p></div>"
    end
  end

  describe "Numerical" do
    it "handles a basic numerical question" do
      qti_file = File.new("spec/fixtures/numerical.qti.xml")
      qti = qti_file.read
      question_type, question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(question_type).to eq "question"
      expect(learnosity[:type]).to eq "formulaV2"
      expect(learnosity[:stimulus]).to eq "<div><p>Numerical answer (1, 2, 3 or 1.2 work)</p></div>"
      expect(learnosity[:validation]).to eq({
        "scoring_type"=>"exactMatch",
        "valid_response" => {
          "value" => [{"method"=>"equivValue", "value"=>"1.2\\pm0.05", "score"=>2.0}]
        },
        "alt_responses"=> [
          { "value"=>[{ "method"=> "equivValue", "value"=>"1.0\\pm0.1", "score"=>2.0 }] },
          { "value"=>[{ "method"=> "equivValue", "value"=>"2.0\\pm0.1", "score"=>2.0 }] },
          { "value"=>[{ "method"=> "equivValue", "value"=>"3.0\\pm0.1", "score"=>2.0 }] },
          { "value"=>[{ "method"=> "equivValue", "value"=>"8.0\\pm3.0", "score"=>2.0 }] },
        ]
      })
    end
  end

  describe "Calculated" do
    it "handles a basic calculated question" do
      qti_file = File.new("spec/fixtures/calculated.qti.xml")
      qti = qti_file.read
      question_type, question = CanvasQtiToLearnosityConverter.convert_item(qti_string: qti)

      dynamic_data = question.dynamic_content_data()

      expect(dynamic_data[:cols]).to eq(["val0", "val1", "val2", "answer"])
      expect(dynamic_data[:rows].keys.count).to eq 10
      row_key = dynamic_data[:rows].keys.first
      expect(dynamic_data[:rows][row_key][:values].count).to eq 4
      learnosity = question.to_learnosity

      expect(question_type).to eq "question"
      expect(learnosity[:type]).to eq "clozeformula"
      expect(learnosity[:stimulus]).to eq "<div><p>1 + {{var:val0}} + {{var:val1}} + {{var:val2}} = ?</p></div>"
      expect(learnosity[:template]).to eq "{{response}}"
      expect(learnosity[:validation]).to eq({
        "scoring_type"=>"exactMatch",
        "valid_response" => {
          "score" => 3.0,
          "value" => [[{"method"=>"equivValue", "value"=>"{{var:answer}}\\pm0.23"}]]
        }
      })
    end
  end

  describe "Convert canvas quiz items" do
    it "handles qti strings" do
      qti_string = CanvasQtiToLearnosityConverter.
        read_file(fixture_path("all_question_types.qti.xml"))

      result = CanvasQtiToLearnosityConverter.convert(qti_string, {}, {})

      expect(result[:title]).to eql("All Questions")
      expect(result[:ident]).to eql("i68e7925af6a9e291012ad7e532e56c0b")
      expect(result[:items].size).to eql 13
    end
  end

  describe "Imscc Export" do
    it "Converts imscc export package of quizzes" do
      result = CanvasQtiToLearnosityConverter.convert_imscc_export(fixture_path("imscc.zip"))

      expect(result[:assessments].size).to eql(1)
      expect(result[:assessments].first[:title]).to eql("All Questions")
    end

    it "Converts a Canvas course export package" do
      result = CanvasQtiToLearnosityConverter.convert_imscc_export(fixture_path("canvas.imscc"))

      expect(result[:assessments].size).to eql(2)
      expect(result[:assessments][0][:title]).to eql("All Questions")
      expect(result[:assessments][0][:items].count).to eql(13)
    end

    it "Converts Canvas new quizzes" do
      result = CanvasQtiToLearnosityConverter.convert_imscc_export(fixture_path("canvas.imscc"))

      expect(result[:assessments].size).to eql(2)
      expect(result[:assessments][1][:title]).to eql("All Questions New Quizzes")
      expect(result[:assessments][1][:items].count).to eql(13)
    end

    it "Converts a D2L CC export package" do
      result = CanvasQtiToLearnosityConverter.convert_imscc_export(fixture_path("D2LCCExport.imscc"))

      expect(result[:assessments].size).to eql(1)
      expect(result[:assessments][0][:title]).to eql("Quiz1")
      expect(result[:assessments][0][:items].count).to eql(4)
    end
  end

end
