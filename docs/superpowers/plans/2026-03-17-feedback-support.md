# Feedback Support Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract `itemfeedback` elements from Canvas QTI and populate Learnosity `metadata` fields (correct_feedback, general_feedback, incorrect_feedback, distractor_rationale_response_level).

**Architecture:** Add `extract_feedback` to the `QuizQuestion` base class, then update `convert` in the same class to merge the result into `metadata`. No individual question type files require changes — all feedback idents are at the item level and follow the same extraction pattern regardless of question type.

**Tech Stack:** Ruby, Nokogiri, RSpec

---

## Chunk 1: All Changes

### Task 1: Add `extract_feedback` and tests

**Files:**
- Modify: `lib/canvas_qti_to_learnosity_converter/questions/question.rb`
- Test: `spec/canvas_qti_to_learnosity_converter_spec.rb`

The QTI structure for all feedback:
```xml
<item>
  <itemfeedback ident="abc123_fb">         <!-- per-answer distractor rationale -->
    <flow_mat><material><mattext texttype="text/html">&lt;p&gt;Answer A feedback&lt;/p&gt;</mattext></material></flow_mat>
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
```

- [ ] **Step 1: Write the failing tests for `extract_feedback`**

Add a new `describe "feedback"` block to `spec/canvas_qti_to_learnosity_converter_spec.rb` before the final `end` at line 1063. The insertion point looks like:

```ruby
  # ...existing tests...
  end
end  # <-- insert describe "feedback" do ... end before this line
```

Full block to insert:

```ruby
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
end
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
bundle exec rspec spec/canvas_qti_to_learnosity_converter_spec.rb -e "feedback" --format documentation
```

Expected: 3 failures with `NoMethodError: undefined method 'extract_feedback'`

- [ ] **Step 3: Implement `extract_feedback` in the base class**

Add the following method to `lib/canvas_qti_to_learnosity_converter/questions/question.rb`, between the `extract_points_possible` method and the `extract_mattext` method:

```ruby
def extract_feedback
  feedback = {}
  distractor_rationale = []

  @xml.css("item > itemfeedback").each do |node|
    ident = node.attribute("ident")&.value
    text = node.css("flow_mat > material > mattext").first&.content
    next if text.nil? || text.empty?

    case ident
    when "correct_fb"           then feedback[:correct_feedback] = text
    when "general_fb"           then feedback[:general_feedback] = text
    when "general_incorrect_fb" then feedback[:incorrect_feedback] = text
    else distractor_rationale << text if ident&.end_with?("_fb")
    end
  end

  feedback[:distractor_rationale_response_level] = distractor_rationale unless distractor_rationale.empty?
  feedback
end
```

- [ ] **Step 4: Run the feedback tests to verify they pass**

```bash
bundle exec rspec spec/canvas_qti_to_learnosity_converter_spec.rb -e "feedback" --format documentation
```

Expected: 5 examples, 0 failures

- [ ] **Step 5: Run the full test suite to make sure nothing is broken**

```bash
bundle exec rspec
```

Expected: all existing tests still pass

- [ ] **Step 6: Commit**

```bash
git add lib/canvas_qti_to_learnosity_converter/questions/question.rb spec/canvas_qti_to_learnosity_converter_spec.rb
git commit -m "feat: add extract_feedback to QuizQuestion base class"
```

---

### Task 2: Wire feedback into `convert` and add integration test

**Files:**
- Modify: `lib/canvas_qti_to_learnosity_converter/questions/question.rb`
- Test: `spec/canvas_qti_to_learnosity_converter_spec.rb`

- [ ] **Step 1: Write a failing integration test**

Add one more test inside the `describe "feedback"` block, after the existing three:

```ruby
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
```

- [ ] **Step 2: Run the new tests to verify they fail**

```bash
bundle exec rspec spec/canvas_qti_to_learnosity_converter_spec.rb -e "feedback" --format documentation
```

Expected: 2 new failures — `convert` does not yet merge feedback into the output

- [ ] **Step 3: Update `convert` in the base class**

Replace the existing `convert` method in `lib/canvas_qti_to_learnosity_converter/questions/question.rb` (currently lines 88–91):

```ruby
# Before:
def convert(assets, path)
  object = to_learnosity
  add_learnosity_assets(assets, path, object)
end
```

With:

```ruby
# After:
def convert(assets, path)
  object = to_learnosity
  add_learnosity_assets(assets, path, object)

  feedback = extract_feedback
  unless feedback.empty?
    object[:metadata] ||= {}
    object[:metadata].merge!(feedback)
  end

  object
end
```

- [ ] **Step 4: Run the feedback tests to verify all 7 pass**

```bash
bundle exec rspec spec/canvas_qti_to_learnosity_converter_spec.rb -e "feedback" --format documentation
```

Expected: 7 examples, 0 failures

- [ ] **Step 5: Run the full test suite**

```bash
bundle exec rspec
```

Expected: all tests pass

- [ ] **Step 6: Commit**

```bash
git add lib/canvas_qti_to_learnosity_converter/questions/question.rb spec/canvas_qti_to_learnosity_converter_spec.rb
git commit -m "feat: include feedback metadata in convert output"
```
