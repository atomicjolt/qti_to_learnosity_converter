# Shuffle Support Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Read the Canvas QTI `shuffle` attribute for MCQ, Multiple Answers, Ordering, and Matching questions and emit `shuffle_options: true/false` in Learnosity output instead of hardcoding or omitting it.

**Architecture:** Per-class extraction — each question class reads its own shuffle attribute from the QTI XML in `to_learnosity`. No shared abstraction needed since each type uses a different XML path. Default is `false` when the attribute is absent.

**Tech Stack:** Ruby, RSpec, Nokogiri (XML parsing)

---

## QTI Attribute Locations (reference)

| Question type | QTI element | Attribute |
|---|---|---|
| MCQ / Multiple Answers | `item > presentation > response_lid > render_choice` | `shuffle="Yes\|No"` |
| Ordering | `ims_render_object` | `shuffle="Yes\|No"` |
| Matching | `item > presentation > response_lid > render_choice` | Not present in Canvas exports — default `false` |

## How to run tests

```bash
bundle exec rspec
```

---

### Task 1: MCQ — `shuffle_options` from `render_choice @shuffle`

**Files:**
- Modify: `spec/canvas_qti_to_learnosity_converter_spec.rb` (around line 4 — the "multiple choice" describe block)
- Modify: `lib/canvas_qti_to_learnosity_converter/questions/multiple_choice.rb:81-90`

**Step 1: Write the failing tests**

In `spec/canvas_qti_to_learnosity_converter_spec.rb`, inside the `describe "multiple choice"` block (after the existing `it` block), add:

```ruby
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
```

**Step 2: Run tests to verify they fail**

```bash
bundle exec rspec spec/canvas_qti_to_learnosity_converter_spec.rb -e "shuffle_options" --format documentation
```

Expected: 3 failures — `expected nil to eq true/false`

**Step 3: Implement in `multiple_choice.rb`**

In `MultipleChoiceQuestion#to_learnosity` (around line 81), add `shuffle_options`:

```ruby
def to_learnosity
  shuffle = @xml.css("item > presentation > response_lid > render_choice").first&.attribute("shuffle")&.value
  {
    stimulus: extract_stimulus(),
    options: extract_options(),
    multiple_responses: false,
    shuffle_options: shuffle == "Yes",
    response_id: extract_response_id(),
    type: "mcq",
    validation: extract_validation(),
  }
end
```

**Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/canvas_qti_to_learnosity_converter_spec.rb -e "shuffle_options" --format documentation
```

Expected: 3 examples, 0 failures

**Step 5: Run full test suite**

```bash
bundle exec rspec
```

Expected: all pass

**Step 6: Commit**

```bash
git add spec/canvas_qti_to_learnosity_converter_spec.rb lib/canvas_qti_to_learnosity_converter/questions/multiple_choice.rb
git commit -m "Add shuffle_options support for multiple choice questions"
```

---

### Task 2: Multiple Answers — `shuffle_options` from `render_choice @shuffle`

`MultipleAnswersQuestion` inherits from `MultipleChoiceQuestion` but overrides `to_learnosity`, so it needs its own `shuffle_options` line.

**Files:**
- Modify: `spec/canvas_qti_to_learnosity_converter_spec.rb` (find the "multiple answer" describe block)
- Modify: `lib/canvas_qti_to_learnosity_converter/questions/multiple_choice.rb:110-120` (`MultipleAnswersQuestion#to_learnosity`)

**Step 1: Write the failing test**

Find the multiple answers describe block in the spec file and add:

```ruby
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
```

**Step 2: Run test to verify it fails**

```bash
bundle exec rspec spec/canvas_qti_to_learnosity_converter_spec.rb -e "multiple answer" --format documentation
```

Expected: new test fails — `expected nil to eq true`

**Step 3: Implement in `MultipleAnswersQuestion#to_learnosity`**

```ruby
def to_learnosity
  shuffle = @xml.css("item > presentation > response_lid > render_choice").first&.attribute("shuffle")&.value
  {
    stimulus: extract_stimulus(),
    options: extract_options(),
    multiple_responses: true,
    shuffle_options: shuffle == "Yes",
    response_id: extract_response_id(),
    type: "mcq",
    validation: extract_validation()
  }
end
```

**Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/canvas_qti_to_learnosity_converter_spec.rb -e "multiple answer" --format documentation
```

Expected: all pass

**Step 5: Run full test suite**

```bash
bundle exec rspec
```

Expected: all pass

**Step 6: Commit**

```bash
git add spec/canvas_qti_to_learnosity_converter_spec.rb lib/canvas_qti_to_learnosity_converter/questions/multiple_choice.rb
git commit -m "Add shuffle_options support for multiple answers questions"
```

---

### Task 3: Ordering — `shuffle_options` from `ims_render_object @shuffle`

The ordering fixture (`spec/fixtures/ordering.qti.xml`) already has `shuffle="No"` on `ims_render_object`.

**Files:**
- Modify: `spec/canvas_qti_to_learnosity_converter_spec.rb` (around line 564 — the "Ordering" describe block)
- Modify: `lib/canvas_qti_to_learnosity_converter/questions/ordering.rb:5-12`

**Step 1: Write the failing tests**

Inside the `describe "Ordering"` block, add after the existing test:

```ruby
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
```

**Step 2: Run tests to verify they fail**

```bash
bundle exec rspec spec/canvas_qti_to_learnosity_converter_spec.rb -e "Ordering" --format documentation
```

Expected: new tests fail — `expected nil to eq false/true`

**Step 3: Implement in `ordering.rb`**

```ruby
def to_learnosity
  shuffle = @xml.css("ims_render_object").first&.attribute("shuffle")&.value
  {
    type: "orderlist",
    stimulus: extract_stimulus(),
    list: extract_items(),
    shuffle_options: shuffle == "Yes",
    validation: extract_validation(),
  }
end
```

**Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/canvas_qti_to_learnosity_converter_spec.rb -e "Ordering" --format documentation
```

Expected: all pass

**Step 5: Run full test suite**

```bash
bundle exec rspec
```

Expected: all pass

**Step 6: Commit**

```bash
git add spec/canvas_qti_to_learnosity_converter_spec.rb lib/canvas_qti_to_learnosity_converter/questions/ordering.rb
git commit -m "Add shuffle_options support for ordering questions"
```

---

### Task 4: Matching — replace hardcoded `true` with `render_choice @shuffle`

Canvas does not encode shuffle in QTI for matching questions, so the attribute will be absent and will default to `false`. The current hardcoded `true` needs to be replaced.

**Files:**
- Modify: `spec/canvas_qti_to_learnosity_converter_spec.rb` (around line 190 — the "Matching" describe block)
- Modify: `lib/canvas_qti_to_learnosity_converter/questions/matching.rb:6-14`

**Step 1: Write the failing tests**

Inside `describe "Matching"`, add after the existing test. Note the existing test does **not** assert `shuffle_options`, so also update it to assert `shuffle_options: false` (since the fixture has no shuffle attribute):

Update the existing matching test to add:
```ruby
expect(learnosity[:shuffle_options]).to eq false
```

Then add a new test:
```ruby
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
```

**Step 2: Run tests to verify they fail**

```bash
bundle exec rspec spec/canvas_qti_to_learnosity_converter_spec.rb -e "Matching" --format documentation
```

Expected: the updated existing test fails (`expected true to eq false`), new test fails

**Step 3: Implement in `matching.rb`**

Replace `shuffle_options: true` with:

```ruby
def to_learnosity
  shuffle = @xml.css("item > presentation > response_lid > render_choice").first&.attribute("shuffle")&.value
  {
    type: "clozedropdown",
    stimulus: extract_stimulus(),
    template: extract_template(),
    validation: extract_validation(),
    possible_responses: extract_responses(),
    duplicate_responses: true,
    shuffle_options: shuffle == "Yes",
  }
end
```

**Step 4: Run tests to verify they pass**

```bash
bundle exec rspec spec/canvas_qti_to_learnosity_converter_spec.rb -e "Matching" --format documentation
```

Expected: all pass

**Step 5: Run full test suite**

```bash
bundle exec rspec
```

Expected: all pass

**Step 6: Commit**

```bash
git add spec/canvas_qti_to_learnosity_converter_spec.rb lib/canvas_qti_to_learnosity_converter/questions/matching.rb
git commit -m "Replace hardcoded shuffle_options with QTI attribute read for matching questions"
```
