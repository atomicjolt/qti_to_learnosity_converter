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

    it "sets shuffle_options true when render_choice has shuffle=Yes" do
      qti = <<~XML
        <item ident="test" title="Q">
          <itemmetadata>
            <qtimetadata>
              <qtimetadatafield><fieldlabel>question_type</fieldlabel><fieldentry>multiple_choice_question</fieldentry></qtimetadatafield>
              <qtimetadatafield><fieldlabel>points_possible</fieldlabel><fieldentry>1.0</fieldentry></qtimetadatafield>
            </qtimetadata>
          </itemmetadata>
          <presentation>
            <material><mattext texttype="text/html">Q?</mattext></material>
            <response_lid ident="response1" rcardinality="Single">
              <render_choice shuffle="Yes">
                <response_label ident="a"><material><mattext texttype="text/plain">A</mattext></material></response_label>
              </render_choice>
            </response_lid>
          </presentation>
          <resprocessing>
            <outcomes><decvar maxvalue="100" minvalue="0" varname="SCORE" vartype="Decimal"/></outcomes>
            <respcondition continue="No"><conditionvar><varequal respident="response1">a</varequal></conditionvar><setvar action="Set" varname="SCORE">100</setvar></respcondition>
          </resprocessing>
        </item>
      XML
      _, question = subject.convert_item(qti_string: qti)
      expect(question.to_learnosity[:shuffle_options]).to eq true
    end

    it "sets shuffle_options false when render_choice has shuffle=No" do
      qti = <<~XML
        <item ident="test" title="Q">
          <itemmetadata>
            <qtimetadata>
              <qtimetadatafield><fieldlabel>question_type</fieldlabel><fieldentry>multiple_choice_question</fieldentry></qtimetadatafield>
              <qtimetadatafield><fieldlabel>points_possible</fieldlabel><fieldentry>1.0</fieldentry></qtimetadatafield>
            </qtimetadata>
          </itemmetadata>
          <presentation>
            <material><mattext texttype="text/html">Q?</mattext></material>
            <response_lid ident="response1" rcardinality="Single">
              <render_choice shuffle="No">
                <response_label ident="a"><material><mattext texttype="text/plain">A</mattext></material></response_label>
              </render_choice>
            </response_lid>
          </presentation>
          <resprocessing>
            <outcomes><decvar maxvalue="100" minvalue="0" varname="SCORE" vartype="Decimal"/></outcomes>
            <respcondition continue="No"><conditionvar><varequal respident="response1">a</varequal></conditionvar><setvar action="Set" varname="SCORE">100</setvar></respcondition>
          </resprocessing>
        </item>
      XML
      _, question = subject.convert_item(qti_string: qti)
      expect(question.to_learnosity[:shuffle_options]).to eq false
    end

    it "sets shuffle_options false when render_choice has no shuffle attribute" do
      qti_file = File.new("spec/fixtures/multiple_choice.qti.xml")
      _, question = subject.convert_item(qti_string: qti_file.read)
      expect(question.to_learnosity[:shuffle_options]).to eq false
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
    it "transforms audio with a local asset src into a learnosity audioplayer span" do
      qti = <<~XML
        <questestinterop>
          <item ident="iaudio" title="Audio Passage">
            <itemmetadata>
              <qtimetadata>
                <qtimetadatafield>
                  <fieldlabel>question_type</fieldlabel>
                  <fieldentry>text_only_question</fieldentry>
                </qtimetadatafield>
              </qtimetadata>
            </itemmetadata>
            <presentation>
              <material>
                <mattext texttype="text/html">&lt;audio&gt;&lt;source src="$IMS-CC-FILEBASE$/Uploaded%20Media/audio-file.mp3"/&gt;&lt;/audio&gt;</mattext>
              </material>
            </presentation>
          </item>
        </questestinterop>
      XML

      _, question = subject.convert_item(qti_string: qti)
      assets = {}
      learnosity = question.to_learnosity
      question.add_learnosity_assets(assets, '', learnosity)

      expect(assets).to match({
        "/Uploaded Media/audio-file.mp3" => end_with('.mp3')
      })
      expect(learnosity[:content]).to include('class="learnosity-feature"')
      expect(learnosity[:content]).to include('data-type="audioplayer"')
      expect(learnosity[:content]).to include("___EXPORT_ROOT___/assets/")
    end

    it "transforms audio with an https src into a learnosity audioplayer span without asset processing" do
      qti = <<~XML
        <questestinterop>
          <item ident="iaudio" title="Audio Passage">
            <itemmetadata>
              <qtimetadata>
                <qtimetadatafield>
                  <fieldlabel>question_type</fieldlabel>
                  <fieldentry>text_only_question</fieldentry>
                </qtimetadatafield>
              </qtimetadata>
            </itemmetadata>
            <presentation>
              <material>
                <mattext texttype="text/html">&lt;audio&gt;&lt;source src="https://assets.learnosity.com/organisations/377/audio.mp3"/&gt;&lt;/audio&gt;</mattext>
              </material>
            </presentation>
          </item>
        </questestinterop>
      XML

      _, question = subject.convert_item(qti_string: qti)
      assets = {}
      learnosity = question.to_learnosity
      question.add_learnosity_assets(assets, '', learnosity)

      expect(assets).to be_empty
      expect(learnosity[:content]).to include('class="learnosity-feature"')
      expect(learnosity[:content]).to include('data-type="audioplayer"')
      expect(learnosity[:content]).to include('data-src="https://assets.learnosity.com/organisations/377/audio.mp3"')
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

    it "sets shuffle_options true when render_choice has shuffle=Yes" do
      qti = <<~XML
        <item ident="test" title="Q">
          <itemmetadata>
            <qtimetadata>
              <qtimetadatafield><fieldlabel>question_type</fieldlabel><fieldentry>multiple_answers_question</fieldentry></qtimetadatafield>
              <qtimetadatafield><fieldlabel>points_possible</fieldlabel><fieldentry>1.0</fieldentry></qtimetadatafield>
            </qtimetadata>
          </itemmetadata>
          <presentation>
            <material><mattext texttype="text/html">Q?</mattext></material>
            <response_lid ident="response1" rcardinality="Multiple">
              <render_choice shuffle="Yes">
                <response_label ident="a"><material><mattext texttype="text/plain">A</mattext></material></response_label>
              </render_choice>
            </response_lid>
          </presentation>
          <resprocessing>
            <outcomes><decvar maxvalue="100" minvalue="0" varname="SCORE" vartype="Decimal"/></outcomes>
            <respcondition continue="No"><conditionvar><and><varequal respident="response1">a</varequal></and></conditionvar><setvar action="Set" varname="SCORE">100</setvar></respcondition>
          </resprocessing>
        </item>
      XML
      _, question = subject.convert_item(qti_string: qti)
      expect(question.to_learnosity[:shuffle_options]).to eq true
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
      expect(learnosity[:shuffle_options]).to eq false
    end

    it "sets shuffle_options true when render_choice has shuffle=Yes" do
      qti = <<~XML
        <item ident="test" title="Q">
          <itemmetadata>
            <qtimetadata>
              <qtimetadatafield><fieldlabel>question_type</fieldlabel><fieldentry>matching_question</fieldentry></qtimetadatafield>
              <qtimetadatafield><fieldlabel>points_possible</fieldlabel><fieldentry>1.0</fieldentry></qtimetadatafield>
            </qtimetadata>
          </itemmetadata>
          <presentation>
            <material><mattext texttype="text/html">Match these</mattext></material>
            <response_lid ident="response_1">
              <material><mattext texttype="text/plain">Left 1</mattext></material>
              <render_choice shuffle="Yes">
                <response_label ident="1"><material><mattext>Right 1</mattext></material></response_label>
              </render_choice>
            </response_lid>
          </presentation>
          <resprocessing>
            <outcomes><decvar maxvalue="100" minvalue="0" varname="SCORE" vartype="Decimal"/></outcomes>
            <respcondition><conditionvar><varequal respident="response_1">1</varequal></conditionvar><setvar action="Add" varname="SCORE">100.00</setvar></respcondition>
          </resprocessing>
        </item>
      XML
      _, question = subject.convert_item(qti_string: qti)
      expect(question.to_learnosity[:shuffle_options]).to eq true
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

  describe "Fill The Blanks Question - dropdown" do
    it "produces clozedropdown when all blanks are dropdowns" do
      qti = File.read("spec/fixtures/fill_blanks_dropdown.qti.xml")
      _, question = subject.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(learnosity[:type]).to eq "clozedropdown"
      expect(learnosity[:template]).to eq "<p>The {{response}} car is {{response}}</p>"
      expect(learnosity[:possible_responses]).to eq [["red", "blue"], ["fast", "slow"]]
      expect(learnosity[:validation]).to eq({
        "scoring_type" => "partialMatchV2",
        "rounding" => "none",
        "valid_response" => {
          "value" => ["red", "fast"],
          "score" => 2.0,
        }
      })
    end
  end

  describe "Fill The Blanks Question - word bank" do
    it "produces clozeassociation when all blanks are wordbank" do
      qti = File.read("spec/fixtures/fill_blanks_wordbank.qti.xml")
      _, question = subject.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(learnosity[:type]).to eq "clozeassociation"
      expect(learnosity[:template]).to eq "<p>The {{response}} car is {{response}}</p>"
      expect(learnosity[:possible_responses]).to eq ["red", "blue", "fast", "slow"]
      expect(learnosity[:validation]).to eq({
        "scoring_type" => "partialMatchV2",
        "rounding" => "none",
        "valid_response" => {
          "value" => ["red", "fast"],
          "score" => 2.0,
        }
      })
    end
  end

  describe "Fill The Blanks Question - mixed types" do
    it "raises MixedFillBlanksTypeError during convert_item when blanks and dropdowns are mixed" do
      qti = File.read("spec/fixtures/fill_blanks_mixed.qti.xml")

      expect { subject.convert_item(qti_string: qti) }.to raise_error(
        CanvasQtiToLearnosityConverter::MixedFillBlanksTypeError,
        /fill-in-the-blank and dropdown/
      )
    end

    it "records an error and skips the item during full assessment conversion" do
      qti = <<~XML
        <questestinterop>
          <assessment ident="test_assessment" title="Test">
            <section ident="root_section">
              #{File.read("spec/fixtures/fill_blanks_mixed.qti.xml")}
            </section>
          </assessment>
        </questestinterop>
      XML

      subject.convert_assessment(qti, "/")

      expect(subject.items).to be_empty
      expect(subject.errors["ifillblanks_mixed"]).to include(
        hash_including(error_type: "MixedFillBlanksTypeError")
      )
    end
  end

  describe "Unsupported question type" do
    it "records an unsupported_question error with the correct type and message" do
      qti = <<~XML
        <questestinterop>
          <assessment ident="test_assessment" title="Test">
            <section ident="root_section">
              <item ident="iunknown" title="Unknown Question">
                <itemmetadata>
                  <qtimetadata>
                    <qtimetadatafield>
                      <fieldlabel>question_type</fieldlabel>
                      <fieldentry>some_unknown_type</fieldentry>
                    </qtimetadatafield>
                  </qtimetadata>
                </itemmetadata>
              </item>
            </section>
          </assessment>
        </questestinterop>
      XML

      subject.convert_assessment(qti, "/")

      expect(subject.errors["iunknown"]).to include(
        hash_including(
          error_type: "unsupported_question",
          message: "Unsupported question type some_unknown_type"
        )
      )
    end
  end

  describe "Too many questions" do
    it "records a too_many_questions error when a stimulus exceeds the maximum child question limit" do
      max = CanvasQtiToLearnosityConverter::Converter::MAX_QUESTIONS_PER_ITEM
      child_items = (1..(max + 1)).map do |i|
        <<~XML
          <item ident="ichild_#{i}" title="Child #{i}">
            <itemmetadata>
              <qtimetadata>
                <qtimetadatafield>
                  <fieldlabel>question_type</fieldlabel>
                  <fieldentry>essay_question</fieldentry>
                </qtimetadatafield>
                <qtimetadatafield>
                  <fieldlabel>parent_stimulus_item_ident</fieldlabel>
                  <fieldentry>istimulus</fieldentry>
                </qtimetadatafield>
              </qtimetadata>
            </itemmetadata>
            <presentation>
              <material>
                <mattext>Essay question #{i}</mattext>
              </material>
            </presentation>
          </item>
        XML
      end.join("\n")

      qti = <<~XML
        <questestinterop>
          <assessment ident="test_assessment" title="Test">
            <section ident="root_section">
              <item ident="istimulus" title="Stimulus">
                <itemmetadata>
                  <qtimetadata>
                    <qtimetadatafield>
                      <fieldlabel>question_type</fieldlabel>
                      <fieldentry>text_only_question</fieldentry>
                    </qtimetadatafield>
                  </qtimetadata>
                </itemmetadata>
                <presentation>
                  <material orientation="left">
                    <mattext>Read this passage.</mattext>
                  </material>
                </presentation>
              </item>
              #{child_items}
            </section>
          </assessment>
        </questestinterop>
      XML

      subject.convert_assessment(qti, "/")

      expect(subject.errors["istimulus"]).to include(
        hash_including(
          error_type: "too_many_questions",
          message: "Too many questions for item, only the first #{max} will be included"
        )
      )
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

      expect(dynamic_data[:cols]).to eq(["x", "y", "z", "seed", "decimal"])
      expect(dynamic_data[:rows].keys.count).to eq 10
      row_key = dynamic_data[:rows].keys.first
      expect(dynamic_data[:rows][row_key][:values].count).to eq 5
      learnosity = question.to_learnosity

      expect(question_type).to eq "question"
      expect(learnosity[:type]).to eq "clozeformulaV2"
      expect(learnosity[:is_dynamic_content]).to eq true
      expect(learnosity[:stimulus]).to be_nil
      expect(learnosity[:template]).to eq "<div><p>1 + {{var:x}} + {{var:y}} + {{var:z}} = ?</p></div>{{response}}"
      expect(learnosity[:validation]).to eq({
        "scoring_type"=>"exactMatch",
        "valid_response" => {
          "score" => 3.0,
          "value" => [[{"method"=>"equivValue", "value"=>"{{var:decimal}}", "options"=>{"decimalPlaces"=>4}}]]
        }
      })
    end

    it "builds MQG item_metadata with dynamic_content from Classic Quizzes fixture" do
      qti_file = File.new("spec/fixtures/calculated.qti.xml")
      qti = qti_file.read
      _question_type, question = subject.convert_item(qti_string: qti)

      dc = question.item_metadata[:dynamic_content]

      expect(dc[:parameters]).to eq([
        { name: "x", type: "range", min: "1.0", max: "10.0", step: 0.001 },
        { name: "y", type: "range", min: "1.0", max: "10.0", step: 0.001 },
        { name: "z", type: "range", min: "1.0", max: "10.0", step: 0.001 },
      ])

      gm = dc[:generated_math]
      expect(gm[:type]).to eq "formula"
      expect(gm[:seed]).to eq "1+x+y+z"
      expect(gm[:response]).to eq ["decimal"]
      expect(gm[:context]).to eq "<div><p>1 + {x} + {y} + {z} = ?</p></div>"
      expect(gm[:template]).to eq "{response==seed}"
      expect(gm[:params]).to eq [["x", "y", "z"], ["1.0..10.0:0.001", "1.0..10.0:0.001", "1.0..10.0:0.001"]]
      expect(gm[:count]).to eq 10
      expect(gm[:limit]).to eq 10
      expect(gm[:data].length).to eq 10
      expect(gm[:data].first).to eq({
        val: [
          { name: "x", val: "3.199" },
          { name: "y", val: "9.916" },
          { name: "z", val: "8.003" },
          { name: "decimal", val: "22.118" },
        ]
      })
    end

    it "builds MQG item_metadata with dynamic_content from New Quizzes fixture" do
      qti_file = File.new("spec/fixtures/calculated_new_quizzes.qti.xml")
      qti = qti_file.read
      _question_type, question = subject.convert_item(qti_string: qti)

      dc = question.item_metadata[:dynamic_content]

      expect(dc[:parameters]).to eq([
        { name: "w", type: "range", min: "10", max: "100", step: 1 },
      ])

      gm = dc[:generated_math]
      expect(gm[:seed]).to eq "w*2"
      expect(gm[:context]).to eq "<p>The weight is {w} kg. What is double the weight?</p>"
      expect(gm[:params]).to eq [["w"], ["10..100:1"]]
      expect(gm[:count]).to eq 3
      expect(gm[:data].first).to eq({
        val: [
          { name: "w", val: "50" },
          { name: "decimal", val: "100.0" },
        ]
      })
    end

    it "builds question_data in item_metadata from Classic Quizzes fixture" do
      qti_file = File.new("spec/fixtures/calculated.qti.xml")
      qti = qti_file.read
      _question_type, question = subject.convert_item(qti_string: qti)

      qd = question.item_metadata[:dynamic_content][:question_data]
      expect(qd[:expression]).to eq "1+{{var:x}}+{{var:y}}+{{var:z}}"
      expect(qd[:template]).to eq "<div><p>1 + {{var:x}} + {{var:y}} + {{var:z}} = ?</p></div>{{response}}"
    end

    it "builds validation_data in item_metadata from Classic Quizzes fixture" do
      qti_file = File.new("spec/fixtures/calculated.qti.xml")
      qti = qti_file.read
      _question_type, question = subject.convert_item(qti_string: qti)

      vd = question.item_metadata[:dynamic_content][:validation_data]
      expect(vd[:availableFormats]).to eq([{ name: "decimal", val: "\\(22.118\\)", isSelected: true }])
      expect(vd[:formatsData][:decimal][:value]).to eq([[{
        method: "equivValue",
        value: "{{var:decimal}}",
        options: { decimalPlaces: 4, allowThousandsSeparator: false, setThousandsSeparator: [","], setDecimalSeparator: ["."] }
      }]])
      expect(vd[:options]).to eq({
        score: 3.0, decimalPlaces: "4",
        allowThousandsSeparator: false, setDecimalSeparator: ".", setThousandsSeparator: ","
      })
    end

    it "builds question_data in item_metadata from New Quizzes fixture" do
      qti_file = File.new("spec/fixtures/calculated_new_quizzes.qti.xml")
      qti = qti_file.read
      _question_type, question = subject.convert_item(qti_string: qti)

      qd = question.item_metadata[:dynamic_content][:question_data]
      expect(qd[:expression]).to eq "{{var:w}}*2"
      expect(qd[:template]).to eq "<p>The weight is {{var:w}} kg. What is double the weight?</p>{{response}}"
    end

    it "builds validation_data in item_metadata from New Quizzes fixture" do
      qti_file = File.new("spec/fixtures/calculated_new_quizzes.qti.xml")
      qti = qti_file.read
      _question_type, question = subject.convert_item(qti_string: qti)

      vd = question.item_metadata[:dynamic_content][:validation_data]
      expect(vd[:availableFormats]).to eq([{ name: "decimal", val: "\\(100.0\\)", isSelected: true }])
      expect(vd[:formatsData][:decimal][:value]).to eq([[{
        method: "equivValue",
        value: "{{var:decimal}}",
        options: { decimalPlaces: 1, allowThousandsSeparator: false, setThousandsSeparator: [","], setDecimalSeparator: ["."] }
      }]])
      expect(vd[:options]).to eq({
        score: 1.0, decimalPlaces: "1",
        allowThousandsSeparator: false, setDecimalSeparator: ".", setThousandsSeparator: ","
      })
    end

    it "uses scientific notation format when scientific_notation=true" do
      qti_file = File.new("spec/fixtures/calculated_scientific.qti.xml")
      qti = qti_file.read
      _question_type, question = subject.convert_item(qti_string: qti)

      learnosity = question.to_learnosity
      expect(learnosity[:validation]).to eq({
        "scoring_type" => "exactMatch",
        "valid_response" => {
          "score" => 2.0,
          "value" => [[
            {
              "method" => "equivValue",
              "value" => "{{var:scientific}}",
              "options" => {
                "allowThousandsSeparator" => false,
                "setThousandsSeparator" => [","],
                "setDecimalSeparator" => ["."],
              }
            },
            {
              "method" => "equivSyntax",
              "value" => "\\format{\\scientific}",
              "options" => {
                "allowThousandsSeparator" => false,
                "setThousandsSeparator" => [","],
                "setDecimalSeparator" => ["."],
              }
            }
          ]]
        }
      })

      dc = question.item_metadata[:dynamic_content]
      gm = dc[:generated_math]
      expect(gm[:response]).to eq ["scientific"]
      expect(gm[:data].first).to eq({
        val: [
          { name: "m", val: "5" },
          { name: "scientific", val: "\\(5.0\\times {10^{2}}\\)" },
        ]
      })

      vd = dc[:validation_data]
      expect(vd[:availableFormats]).to eq([{ name: "scientific", val: "\\(5.0\\times {10^{2}}\\)", isSelected: true }])
      expect(vd[:formatsData][:scientific][:value].first).to include(
        a_hash_including(method: "equivSyntax", value: "\\format{\\scientific}")
      )
    end

    it "provides Math Question Generator widget metadata" do
      qti_file = File.new("spec/fixtures/calculated.qti.xml")
      qti = qti_file.read
      _question_type, question = subject.convert_item(qti_string: qti)

      expect(question.widget_metadata).to eq({
        name: "Math Question Generator",
        template_reference: "17149c09-83ba-4b1b-afff-a681e7edd8ff"
      })
    end

    it "handles a New Quizzes calculated question with backtick variable notation" do
      qti_file = File.new("spec/fixtures/calculated_new_quizzes.qti.xml")
      qti = qti_file.read
      question_type, question = subject.convert_item(qti_string: qti)

      dynamic_data = question.dynamic_content_data()

      expect(dynamic_data[:cols]).to eq(["w", "seed", "decimal"])
      expect(dynamic_data[:rows].keys.count).to eq 3
      row_key = dynamic_data[:rows].keys.first
      expect(dynamic_data[:rows][row_key][:values].count).to eq 3

      learnosity = question.to_learnosity

      expect(question_type).to eq "question"
      expect(learnosity[:type]).to eq "clozeformulaV2"
      expect(learnosity[:is_dynamic_content]).to eq true
      expect(learnosity[:stimulus]).to be_nil
      expect(learnosity[:template]).to eq "<p>The weight is {{var:w}} kg. What is double the weight?</p>{{response}}"
      expect(learnosity[:validation]).to eq({
        "scoring_type" => "exactMatch",
        "valid_response" => {
          "score" => 1.0,
          "value" => [[{ "method" => "equivValue", "value" => "{{var:decimal}}", "options" => { "decimalPlaces" => 1 } }]]
        }
      })
    end
  end

  describe "Ordering" do
    it "handles a basic ordering question" do
      qti_file = File.new("spec/fixtures/ordering.qti.xml")
      qti = qti_file.read
      question_type, question = subject.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(question_type).to eq "question"
      expect(learnosity[:type]).to eq "orderlist"
      expect(learnosity[:stimulus]).to include "<p>Preference?</p>"
      expect(learnosity[:list].size).to eq 3
      expect(learnosity[:validation]).to eq({
        "valid_response" => {
          "score" => 1.0,
          "value" => [2, 0, 1]
        }
      })
    end

    it "sets shuffle_options false when ims_render_object has shuffle=No" do
      qti_file = File.new("spec/fixtures/ordering.qti.xml")
      _, question = subject.convert_item(qti_string: qti_file.read)
      expect(question.to_learnosity[:shuffle_options]).to eq false
    end

    it "sets shuffle_options true when ims_render_object has shuffle=Yes" do
      qti = <<~XML
        <item ident="test" title="Q">
          <itemmetadata>
            <qtimetadata>
              <qtimetadatafield><fieldlabel>question_type</fieldlabel><fieldentry>ordering_question</fieldentry></qtimetadatafield>
              <qtimetadatafield><fieldlabel>points_possible</fieldlabel><fieldentry>1.0</fieldentry></qtimetadatafield>
              <qtimetadatafield><fieldlabel>original_answer_ids</fieldlabel><fieldentry>a,b</fieldentry></qtimetadatafield>
            </qtimetadata>
          </itemmetadata>
          <presentation>
            <material><mattext texttype="text/html">Order these</mattext></material>
            <response_lid ident="response1" rcardinality="Ordered">
              <render_extension>
                <ims_render_object shuffle="Yes">
                  <flow_label>
                    <response_label ident="a"><material><mattext texttype="text/html">A</mattext></material></response_label>
                    <response_label ident="b"><material><mattext texttype="text/html">B</mattext></material></response_label>
                  </flow_label>
                </ims_render_object>
              </render_extension>
            </response_lid>
          </presentation>
          <resprocessing>
            <outcomes><decvar defaultval="1" varname="ORDERSCORE" vartype="Integer"/></outcomes>
            <respcondition continue="No">
              <conditionvar>
                <varequal respident="response1">a</varequal>
                <varequal respident="response1">b</varequal>
              </conditionvar>
              <setvar action="Set" varname="SCORE">100</setvar>
            </respcondition>
          </resprocessing>
        </item>
      XML
      _, question = subject.convert_item(qti_string: qti)
      expect(question.to_learnosity[:shuffle_options]).to eq true
    end
  end

  describe "Hot Spot" do
    it "handles a basic hot spot question" do
      qti_file = File.new("spec/fixtures/hotspot.qti.xml")
      qti = qti_file.read
      question_type, question = subject.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(question_type).to eq "question"
      expect(learnosity[:type]).to eq "hotspot"
      expect(learnosity[:stimulus]).to include "<p>This spot is hot</p>"

      expect(learnosity[:image]).to eq({ source: "$IMS-CC-FILEBASE$/Uploaded Media/c99925eb-96d7-400c-bdf0-4ab0c325c332" })

      expect(learnosity[:areas].length).to eq 1
      # Rectangle coords (0-1 fractions) converted to 4 polygon points (0-100 percentages)
      expect(learnosity[:areas][0]).to eq [
        { "x" => 35.346097201767307, "y" => 14.138438880706922 },
        { "x" => 67.59941089837997,  "y" => 14.138438880706922 },
        { "x" => 67.59941089837997,  "y" => 40.942562592047127 },
        { "x" => 35.346097201767307, "y" => 40.942562592047127 },
      ]

      expect(learnosity[:area_attributes]).to eq({
        "global" => {
          "fill" => "rgba(255,255,255,0)",
          "stroke" => "rgba(15,61,109,0.8)"
        },
        "individual" => [
          { "area" => "0", "label" => "1" }
        ]
      })

      expect(learnosity[:validation]).to eq({
        "scoring_type" => "exactMatch",
        "valid_response" => {
          "score" => 1.0,
          "value" => ["0"],
        }
      })
    end

    it "processes hotspot image as an asset" do
      qti_file = File.new("spec/fixtures/hotspot.qti.xml")
      qti = qti_file.read
      _, question = subject.convert_item(qti_string: qti)

      assets = {}
      learnosity = question.to_learnosity
      question.add_learnosity_assets(assets, '', learnosity)

      expect(assets).to match({
        "/Uploaded Media/c99925eb-96d7-400c-bdf0-4ab0c325c332" => be_a(String)
      })
      expect(learnosity[:image][:source]).to start_with("___EXPORT_ROOT___/assets/")
    end
  end

  describe "Categorization" do
    it "handles a basic categorization question" do
      qti_file = File.new("spec/fixtures/categorization.qti.xml")
      qti = qti_file.read
      question_type, question = subject.convert_item(qti_string: qti)

      learnosity = question.to_learnosity

      expect(question_type).to eq "question"
      expect(learnosity[:type]).to eq "classification"
      expect(learnosity[:stimulus]).to include "<p>Blah</p>"

      expect(learnosity[:possible_responses]).to eq ["blah blah", "blah blah blah"]

      expect(learnosity[:ui_style]).to eq({
        "column_count" => 2,
        "column_titles" => ["cat 2 desc", "cat 1 desc"],
      })

      expect(learnosity[:validation]).to eq({
        "scoring_type" => "exactMatch",
        "valid_response" => {
          "score" => 1.0,
          # column 0 (cat 2 / a03061ec): item b9ca0088 (index 1)
          # column 1 (cat 1 / a08633c0): item 20502d90 (index 0)
          "value" => [[1], [0]],
        }
      })
    end
  end

  describe "Convert canvas quiz items" do
    it "sets definition template to dynamic and widget metadata for calculated questions" do
      qti_string = File.read(fixture_path("all_question_types.qti.xml"))
      subject.convert_assessment(qti_string, '/')

      items = subject.items
      widgets = subject.widgets

      calc_item = items.find { |i| i[:dynamic_content_data][:cols]&.any? }
      expect(calc_item[:definition][:template]).to eq "dynamic"

      calc_widget_ref = calc_item[:definition][:widgets].first[:reference]
      calc_widget = widgets.find { |w| w[:reference] == calc_widget_ref }
      expect(calc_widget[:metadata][:name]).to eq "Math Question Generator"
      expect(calc_widget[:metadata][:template_reference]).to eq "17149c09-83ba-4b1b-afff-a681e7edd8ff"
    end

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

  describe "feedback" do
    let(:qti_with_all_feedback) do
      <<~XML
        <item ident="test" title="Q">
          <itemmetadata>
            <qtimetadata>
              <qtimetadatafield><fieldlabel>question_type</fieldlabel><fieldentry>multiple_choice_question</fieldentry></qtimetadatafield>
              <qtimetadatafield><fieldlabel>points_possible</fieldlabel><fieldentry>1.0</fieldentry></qtimetadatafield>
            </qtimetadata>
          </itemmetadata>
          <presentation>
            <material><mattext texttype="text/html">Q?</mattext></material>
            <response_lid ident="response1" rcardinality="Single">
              <render_choice>
                <response_label ident="abc123"><material><mattext texttype="text/plain">A</mattext></material></response_label>
                <response_label ident="def456"><material><mattext texttype="text/plain">B</mattext></material></response_label>
              </render_choice>
            </response_lid>
          </presentation>
          <resprocessing>
            <outcomes><decvar maxvalue="100" minvalue="0" varname="SCORE" vartype="Decimal"/></outcomes>
            <respcondition continue="No"><conditionvar><varequal respident="response1">abc123</varequal></conditionvar><setvar action="Set" varname="SCORE">100</setvar></respcondition>
          </resprocessing>
          <itemfeedback ident="abc123_fb">
            <flow_mat><material><mattext texttype="text/html">&lt;p&gt;Answer A feedback&lt;/p&gt;</mattext></material></flow_mat>
          </itemfeedback>
          <itemfeedback ident="def456_fb">
            <flow_mat><material><mattext texttype="text/html">&lt;p&gt;Answer B feedback&lt;/p&gt;</mattext></material></flow_mat>
          </itemfeedback>
          <itemfeedback ident="correct_fb">
            <flow_mat><material><mattext texttype="text/html">&lt;p&gt;Correct!&lt;/p&gt;</mattext></material></flow_mat>
          </itemfeedback>
          <itemfeedback ident="general_fb">
            <flow_mat><material><mattext texttype="text/html">&lt;p&gt;General feedback&lt;/p&gt;</mattext></material></flow_mat>
          </itemfeedback>
          <itemfeedback ident="general_incorrect_fb">
            <flow_mat><material><mattext texttype="text/html">&lt;p&gt;Incorrect!&lt;/p&gt;</mattext></material></flow_mat>
          </itemfeedback>
        </item>
      XML
    end

    let(:qti_with_general_only) do
      <<~XML
        <item ident="test" title="Q">
          <itemmetadata>
            <qtimetadata>
              <qtimetadatafield><fieldlabel>question_type</fieldlabel><fieldentry>essay_question</fieldentry></qtimetadatafield>
              <qtimetadatafield><fieldlabel>points_possible</fieldlabel><fieldentry>1.0</fieldentry></qtimetadatafield>
            </qtimetadata>
          </itemmetadata>
          <presentation>
            <material><mattext texttype="text/html">Write something.</mattext></material>
            <response_str ident="response1" rcardinality="Single"><render_fib/></response_str>
          </presentation>
          <resprocessing>
            <outcomes><decvar maxvalue="100" minvalue="0" varname="SCORE" vartype="Decimal"/></outcomes>
          </resprocessing>
          <itemfeedback ident="general_fb">
            <flow_mat><material><mattext texttype="text/html">&lt;p&gt;General only&lt;/p&gt;</mattext></material></flow_mat>
          </itemfeedback>
        </item>
      XML
    end

    let(:qti_with_no_feedback) do
      <<~XML
        <item ident="test" title="Q">
          <itemmetadata>
            <qtimetadata>
              <qtimetadatafield><fieldlabel>question_type</fieldlabel><fieldentry>essay_question</fieldentry></qtimetadatafield>
              <qtimetadatafield><fieldlabel>points_possible</fieldlabel><fieldentry>1.0</fieldentry></qtimetadatafield>
            </qtimetadata>
          </itemmetadata>
          <presentation>
            <material><mattext texttype="text/html">Write something.</mattext></material>
            <response_str ident="response1" rcardinality="Single"><render_fib/></response_str>
          </presentation>
          <resprocessing>
            <outcomes><decvar maxvalue="100" minvalue="0" varname="SCORE" vartype="Decimal"/></outcomes>
          </resprocessing>
        </item>
      XML
    end

    it "extracts all feedback types" do
      _, question = subject.convert_item(qti_string: qti_with_all_feedback)
      feedback = question.extract_feedback

      expect(feedback).to eq({
        correct_feedback: "<p>Correct!</p>",
        general_feedback: "<p>General feedback</p>",
        incorrect_feedback: "<p>Incorrect!</p>",
        distractor_rationale_response_level: ["<p>Answer A feedback</p>", "<p>Answer B feedback</p>"],
      })
    end

    it "extracts only the feedback that is present" do
      _, question = subject.convert_item(qti_string: qti_with_general_only)
      feedback = question.extract_feedback

      expect(feedback).to eq({ general_feedback: "<p>General only</p>" })
    end

    it "returns an empty hash when no feedback is present" do
      _, question = subject.convert_item(qti_string: qti_with_no_feedback)
      expect(question.extract_feedback).to eq({})
    end

    it "collects per-answer feedbacks in document order" do
      qti = <<~XML
        <item ident="test" title="Q">
          <itemmetadata>
            <qtimetadata>
              <qtimetadatafield><fieldlabel>question_type</fieldlabel><fieldentry>multiple_choice_question</fieldentry></qtimetadatafield>
              <qtimetadatafield><fieldlabel>points_possible</fieldlabel><fieldentry>1.0</fieldentry></qtimetadatafield>
            </qtimetadata>
          </itemmetadata>
          <presentation>
            <material><mattext texttype="text/html">Q?</mattext></material>
            <response_lid ident="response1" rcardinality="Single">
              <render_choice>
                <response_label ident="first"><material><mattext>A</mattext></material></response_label>
                <response_label ident="second"><material><mattext>B</mattext></material></response_label>
                <response_label ident="third"><material><mattext>C</mattext></material></response_label>
              </render_choice>
            </response_lid>
          </presentation>
          <resprocessing>
            <outcomes><decvar maxvalue="100" minvalue="0" varname="SCORE" vartype="Decimal"/></outcomes>
            <respcondition continue="No"><conditionvar><varequal respident="response1">first</varequal></conditionvar><setvar action="Set" varname="SCORE">100</setvar></respcondition>
          </resprocessing>
          <itemfeedback ident="first_fb">
            <flow_mat><material><mattext texttype="text/html">First</mattext></material></flow_mat>
          </itemfeedback>
          <itemfeedback ident="second_fb">
            <flow_mat><material><mattext texttype="text/html">Second</mattext></material></flow_mat>
          </itemfeedback>
          <itemfeedback ident="third_fb">
            <flow_mat><material><mattext texttype="text/html">Third</mattext></material></flow_mat>
          </itemfeedback>
        </item>
      XML
      _, question = subject.convert_item(qti_string: qti)
      feedback = question.extract_feedback

      expect(feedback[:distractor_rationale_response_level]).to eq(["First", "Second", "Third"])
    end

    it "skips per-answer feedbacks with empty content" do
      qti = <<~XML
        <item ident="test" title="Q">
          <itemmetadata>
            <qtimetadata>
              <qtimetadatafield><fieldlabel>question_type</fieldlabel><fieldentry>multiple_choice_question</fieldentry></qtimetadatafield>
              <qtimetadatafield><fieldlabel>points_possible</fieldlabel><fieldentry>1.0</fieldentry></qtimetadatafield>
            </qtimetadata>
          </itemmetadata>
          <presentation>
            <material><mattext texttype="text/html">Q?</mattext></material>
            <response_lid ident="response1" rcardinality="Single">
              <render_choice>
                <response_label ident="opt1"><material><mattext>A</mattext></material></response_label>
              </render_choice>
            </response_lid>
          </presentation>
          <resprocessing>
            <outcomes><decvar maxvalue="100" minvalue="0" varname="SCORE" vartype="Decimal"/></outcomes>
            <respcondition continue="No"><conditionvar><varequal respident="response1">opt1</varequal></conditionvar><setvar action="Set" varname="SCORE">100</setvar></respcondition>
          </resprocessing>
          <itemfeedback ident="opt1_fb">
            <flow_mat><material><mattext texttype="text/html"></mattext></material></flow_mat>
          </itemfeedback>
          <itemfeedback ident="general_fb">
            <flow_mat><material><mattext texttype="text/html"></mattext></material></flow_mat>
          </itemfeedback>
        </item>
      XML
      _, question = subject.convert_item(qti_string: qti)
      expect(question.extract_feedback).to eq({})
    end

    it "ignores itemfeedback elements with no ident attribute" do
      qti = <<~XML
        <item ident="test" title="Q">
          <itemmetadata>
            <qtimetadata>
              <qtimetadatafield><fieldlabel>question_type</fieldlabel><fieldentry>essay_question</fieldentry></qtimetadatafield>
              <qtimetadatafield><fieldlabel>points_possible</fieldlabel><fieldentry>1.0</fieldentry></qtimetadatafield>
            </qtimetadata>
          </itemmetadata>
          <presentation>
            <material><mattext texttype="text/html">Q?</mattext></material>
            <response_str ident="response1" rcardinality="Single"><render_fib/></response_str>
          </presentation>
          <resprocessing>
            <outcomes><decvar maxvalue="100" minvalue="0" varname="SCORE" vartype="Decimal"/></outcomes>
          </resprocessing>
          <itemfeedback>
            <flow_mat><material><mattext texttype="text/html">&lt;p&gt;Orphan feedback&lt;/p&gt;</mattext></material></flow_mat>
          </itemfeedback>
        </item>
      XML
      _, question = subject.convert_item(qti_string: qti)
      expect(question.extract_feedback).to eq({})
    end

    it "includes feedback in the convert output" do
      _, question = subject.convert_item(qti_string: qti_with_all_feedback)
      result = question.convert({}, "")

      expect(result[:metadata]).to eq({
        correct_feedback: "<p>Correct!</p>",
        general_feedback: "<p>General feedback</p>",
        incorrect_feedback: "<p>Incorrect!</p>",
        distractor_rationale_response_level: ["<p>Answer A feedback</p>", "<p>Answer B feedback</p>"],
      })
    end

    it "does not add a metadata key when there is no feedback" do
      _, question = subject.convert_item(qti_string: qti_with_no_feedback)
      result = question.convert({}, "")

      expect(result).not_to have_key(:metadata)
    end

    it "merges feedback into pre-existing metadata without clobbering it" do
      _, question = subject.convert_item(qti_string: qti_with_all_feedback)
      learnosity_object = {
        type: "mcq",
        stimulus: "Q?",
        metadata: { existing_key: "existing_value" }
      }
      allow(question).to receive(:to_learnosity).and_return(learnosity_object)
      allow(question).to receive(:add_learnosity_assets)

      result = question.convert({}, "")

      expect(result[:metadata]).to include(
        existing_key: "existing_value",
        correct_feedback: "<p>Correct!</p>",
        general_feedback: "<p>General feedback</p>",
      )
    end

    it "rewrites asset references in string feedback fields and collects them" do
      qti = <<~XML
        <item ident="test" title="Q">
          <itemmetadata>
            <qtimetadata><qtimetadatafield><fieldlabel>question_type</fieldlabel><fieldentry>multiple_choice_question</fieldentry></qtimetadatafield></qtimetadata>
          </itemmetadata>
          <presentation>
            <material><mattext texttype="text/html">Q?</mattext></material>
            <response_lid ident="response1" rcardinality="Single">
              <render_choice>
                <response_label ident="opt1"><material><mattext texttype="text/plain">A</mattext></material></response_label>
              </render_choice>
            </response_lid>
          </presentation>
          <resprocessing>
            <outcomes><decvar maxvalue="100" minvalue="0" varname="SCORE" vartype="Decimal"/></outcomes>
            <respcondition continue="No"><conditionvar><varequal respident="response1">opt1</varequal></conditionvar><setvar action="Set" varname="SCORE">100</setvar></respcondition>
          </resprocessing>
          <itemfeedback ident="correct_fb">
            <flow_mat><material><mattext texttype="text/html">&lt;img src="images/hint.png"/&gt;</mattext></material></flow_mat>
          </itemfeedback>
        </item>
      XML
      _, question = subject.convert_item(qti_string: qti)
      assets = {}

      result = question.convert(assets, "")

      expect(assets.keys).to eq(["/images/hint.png"])
      expect(result.dig(:metadata, :correct_feedback)).to match(%r{___EXPORT_ROOT___/assets/.+\.png})
    end

    it "rewrites asset references in distractor rationale entries and collects them" do
      qti = <<~XML
        <item ident="test" title="Q">
          <itemmetadata>
            <qtimetadata><qtimetadatafield><fieldlabel>question_type</fieldlabel><fieldentry>multiple_choice_question</fieldentry></qtimetadatafield></qtimetadata>
          </itemmetadata>
          <presentation>
            <material><mattext texttype="text/html">Q?</mattext></material>
            <response_lid ident="response1" rcardinality="Single">
              <render_choice>
                <response_label ident="opt1"><material><mattext texttype="text/plain">A</mattext></material></response_label>
              </render_choice>
            </response_lid>
          </presentation>
          <resprocessing>
            <outcomes><decvar maxvalue="100" minvalue="0" varname="SCORE" vartype="Decimal"/></outcomes>
            <respcondition continue="No"><conditionvar><varequal respident="response1">opt1</varequal></conditionvar><setvar action="Set" varname="SCORE">100</setvar></respcondition>
          </resprocessing>
          <itemfeedback ident="opt1_fb">
            <flow_mat><material><mattext texttype="text/html">&lt;img src="images/distractor.png"/&gt;</mattext></material></flow_mat>
          </itemfeedback>
        </item>
      XML
      _, question = subject.convert_item(qti_string: qti)
      assets = {}

      result = question.convert(assets, "")

      expect(assets.keys).to eq(["/images/distractor.png"])
      expect(result.dig(:metadata, :distractor_rationale_response_level).first).to match(%r{___EXPORT_ROOT___/assets/.+\.png})
    end
  end
end
