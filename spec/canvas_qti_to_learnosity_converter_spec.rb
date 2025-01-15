RSpec.describe CanvasQtiToLearnosityConverter do
  subject { CanvasQtiToLearnosityConverter::Converter.new }

  describe "multiple choice" do
    it "handles a basic multiple choice question" do
      qti_file = File.new("spec/fixtures/multiple_choice.qti.xml")
      qti = qti_file.read
      question_type, question = subject.convert_item(qti_string: qti)

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
      question_type, question = subject.convert_item(qti_string: qti)
      assets = {}
      question.add_learnosity_assets(assets, [:asset_path], question.to_learnosity)

      expect(assets).to match({
        "/Uploaded Media/apple-1.jpeg" => end_with('.jpeg'),
        "/Uploaded Media/apple-2.jpeg" => end_with('.jpeg'),
      })
    end
    it "detects newer style assets" do
      qti_file = File.new("spec/fixtures/assets_new_style.qti.xml")
      qti = qti_file.read
      question_type, question = subject.convert_item(qti_string: qti)
      assets = {}
      question.add_learnosity_assets(assets, [:asset_path], question.to_learnosity)

      expect(assets).to match({
        "/Uploaded Media/apple-1.jpeg" => end_with('.jpeg'),
        "/Uploaded Media/apple-2.jpeg" => end_with('.jpeg'),
      })
    end
  end

  describe "True False" do
    it "handles a basic true false question" do
      qti_file = File.new("spec/fixtures/true_false.qti.xml")
      qti = qti_file.read
      question_type, question = subject.convert_item(qti_string: qti)

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
      question_type, question = subject.convert_item(qti_string: qti)

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
      question_type, question = subject.convert_item(qti_string: qti)

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
      question_type, question = subject.convert_item(qti_string: qti)

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
      question_type, question = subject.convert_item(qti_string: qti)

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
      question_type, question = subject.convert_item(qti_string: qti)

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
      question_type, question = subject.convert_item(qti_string: qti)

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
      question_type, question = subject.convert_item(qti_string: qti)

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
      question_type, question = subject.convert_item(qti_string: qti)

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
      question_type, question = subject.convert_item(qti_string: qti)

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
      question_type, question = subject.convert_item(qti_string: qti)

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
      qti_string = File.read(fixture_path("all_question_types.qti.xml"))

      out = subject.convert_assessment(qti_string, '/')

      assessments = subject.assessments
      items = subject.items
      widgets = subject.widgets
      expect(assessments[0][:title]).to eql("All Questions")
      expect(assessments[0][:reference]).to_not be_nil
      expect(assessments[0][:data][:items].count).to eql(13)
      expect(items.size).to eql 13
      expect(widgets.size).to eql 13
    end

    describe "with stimulus questions" do
      it "handles a left orientated stimulus question" do
        qti_string = File.read("spec/fixtures/left_stimulus_with_questions.qti.xml")
        subject.convert_assessment(qti_string, '/')

        assessments = subject.assessments
        items = subject.items
        widgets = subject.widgets

        expect(assessments.size).to eql 1
        expect(items.size).to eql 1
        expect(widgets.size).to eql 3

        item = items[0]
        expect(item[:definition][:regions].size).to eql 2
        expect(item[:definition][:regions][0][:widgets].size).to eql 1
        expect(item[:definition][:regions][0][:widgets][0][:reference]).to be_present
        expect(item[:definition][:regions][0][:width]).to eql 50
        expect(item[:definition][:regions][1][:widgets].size).to eql 2
      end

      it "handles a top orientated stimulus question" do
        qti_string = File.read("spec/fixtures/top_stimulus_with_questions.qti.xml")
        subject.convert_assessment(qti_string, '/')

        assessments = subject.assessments
        items = subject.items
        widgets = subject.widgets

        expect(assessments.size).to eql 1
        expect(items.size).to eql 1
        expect(widgets.size).to eql 3

        item = items[0]
        expect(item[:definition][:widgets].size).to eql 3
      end
    end
  end

  describe "Convert canvas item banks" do
    it "handles qti strings" do
      qti_string = File.read(fixture_path("item_bank.qti.xml"))

      out = subject.convert_item_bank(qti_string, '/')

      item_banks = subject.item_banks
      items = subject.items
      widgets = subject.widgets
      expect(item_banks[0][:title]).to eql("My Item Bank")
      expect(item_banks[0][:ident]).to eql("g434648260ca7918cb978a027019f2c1e")
      expect(item_banks[0][:item_refs].count).to eql(3)
      expect(items.size).to eql 3
      expect(items[0][:tags]).to eql({ "Item Bank" => ["My Item Bank"] })
    end
  end

  describe "generate_learnosity_export" do
    let(:output_path) { Tempfile.new(['export', '.zip']) }

    def count_files(out, prefix)
      out.select { |entry| entry.name.start_with?(prefix) }.count
    end

    it "Converts imscc export package with no errors" do
      result = subject.generate_learnosity_export(fixture_path("imscc.zip"), output_path)

      expect(result[:errors]).to eql({})
      expect(File.exist?(output_path)).to be_truthy

      Zip::File.open(output_path) do |out|
        expect(out.find_entry("export.json")).to be_truthy
        expect(count_files(out, "activities/")).to eq(1)
        expect(count_files(out, "items/")).to eq(13)
        expect(count_files(out, "assets/")).to eq(1)
      end
    end

    it "Converts canvas export package with no errors" do
      result = subject.generate_learnosity_export(fixture_path("canvas.imscc"), output_path)

      expect(result[:errors]).to eql({})
      expect(File.exist?(output_path)).to be_truthy

      Zip::File.open(output_path) do |out|
        expect(out.find_entry("export.json")).to be_truthy
        expect(count_files(out, "activities/")).to eq(3)
        expect(count_files(out, "items/")).to eq(43)
        expect(count_files(out, "assets/")).to eq(3)
      end
    end

    it "Converts canvas multi-column new quiz with no errors" do
      result = subject.generate_learnosity_export(fixture_path("canvas_multi.imscc"), output_path)

      expect(result[:errors]).to eql({})
      expect(File.exist?(output_path)).to be_truthy

      Zip::File.open(output_path) do |out|
        expect(out.find_entry("export.json")).to be_truthy
        expect(count_files(out, "activities/")).to eq(1)
        expect(count_files(out, "items/")).to eq(10)
        expect(count_files(out, "assets/")).to eq(0)
      end
    end

    it "Converts D2L CC export package with no errors" do
      result = subject.generate_learnosity_export(fixture_path("D2LCCExport.imscc"), output_path)

      expect(result[:errors]).to eql({})
      expect(File.exist?(output_path)).to be_truthy

      Zip::File.open(output_path) do |out|
        expect(out.find_entry("export.json")).to be_truthy
        expect(count_files(out, "activities/")).to eq(1)
        expect(count_files(out, "items/")).to eq(4)
        expect(count_files(out, "assets/")).to eq(2)
      end
    end
  end

  describe "Imscc Export" do
    it "Converts imscc export package with no errors" do
      result = subject.convert_imscc_export(fixture_path("imscc.zip"))

      expect(result[:errors]).to eql({})
    end

    it "Converts imscc export package of quizzes" do
      result = subject.convert_imscc_export(fixture_path("imscc.zip"))

      expect(subject.assessments.size).to eql(1)
      expect(subject.assessments[0][:title]).to eql("All Questions")
    end

    it "Converts a Canvas course export package with no errors" do
      result = subject.convert_imscc_export(fixture_path("canvas.imscc"))

      expect(result[:errors]).to eql({})
    end

    it "Converts a Canvas course export package" do
      result = subject.convert_imscc_export(fixture_path("canvas.imscc"))

      expect(subject.assessments.size).to eql(3)
      expect(subject.assessments[0][:title]).to eql("All Questions")
      expect(subject.assessments[0][:data][:items].count).to eql(13)
    end

    it "Converts Canvas new quizzes" do
      result = subject.convert_imscc_export(fixture_path("canvas.imscc"))

      expect(subject.assessments.size).to eql(3)
      expect(subject.assessments[1][:title]).to eql("All Questions New Quizzes")
      expect(subject.assessments[1][:data][:items].count).to eql(15)
    end

    it "Converts Canvas new quizzes that use item banks" do
      result = subject.convert_imscc_export(fixture_path("canvas.imscc"))

      expect(subject.assessments.size).to eql(3)
      expect(subject.assessments[2][:title]).to eql("Questions from item bank")
      expect(subject.assessments[2][:data][:items].count).to eql(4)
    end

    it "Converts Canvas multi-column new quizzes" do
      # TODO: add support for multi-column quizzes
      result = subject.convert_imscc_export(fixture_path("canvas_multi.imscc"))

      expect(subject.errors).to eql({})
      expect(subject.assessments.size).to eql(1)
      expect(subject.assessments[0][:title]).to eql("Multi-column quiz")
      expect(subject.assessments[0][:data][:items].count).to eql(5)
      expect(subject.items.count).to eql(10)
      expect(subject.widgets.count).to eql(20)
    end

    it "Converts Canvas new quizzes item banks" do
      result = subject.convert_imscc_export(fixture_path("canvas.imscc"))

      expect(subject.item_banks.size).to eql(3)
      expect(subject.item_banks[0][:title]).to eql("All Questions")
      expect(subject.item_banks[0][:item_refs].count).to eql(13)
      expect(subject.item_banks[1][:title]).to eql("My Item Bank")
      expect(subject.item_banks[1][:item_refs].count).to eql(3)
      expect(subject.item_banks[2][:title]).to eql("My Item Bank 2")
      expect(subject.item_banks[2][:item_refs].count).to eql(1)
    end

    it "Converts all items" do
      result = subject.convert_imscc_export(fixture_path("canvas.imscc"))

      expect(subject.items.size).to eql(43)
    end

    it "Converts all assets" do
      result = subject.convert_imscc_export(fixture_path("canvas.imscc"))

      expect(subject.assets.values.select(&:present?).size).to eql(3)
      expect(subject.assets.keys).to include(
        "/assessment_questions/IMG_2523.JPG",
        "/Quiz Files/imscc_11763/IMG_2523.JPG",
      )
    end

    it "Converts a D2L CC export package" do
      result = subject.convert_imscc_export(fixture_path("D2LCCExport.imscc"))

      expect(subject.assessments.size).to eql(1)
      expect(subject.assessments[0][:title]).to eql("Quiz1")
      expect(subject.assessments[0][:data][:items].count).to eql(4)
    end
  end
end
