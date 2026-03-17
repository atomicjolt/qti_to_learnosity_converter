# Feedback Support Design

**Date:** 2026-03-17
**Status:** Approved

## Problem

Canvas QTI exports include `itemfeedback` elements for correct, incorrect, general, and per-answer feedback. The converter currently ignores all of these, so feedback is lost when importing into Learnosity.

## QTI Feedback Structure

All feedback lives as `itemfeedback` siblings to `presentation` and `resprocessing` inside `item`. The ident attribute determines the type:

| QTI ident | Type |
|---|---|
| `correct_fb` | Shown when the student answers correctly |
| `general_fb` | Always shown after submission |
| `general_incorrect_fb` | Shown when the student answers incorrectly |
| `{anything}_fb` | Per-answer distractor rationale |

The per-answer idents vary by question type (UUIDs for MCQ, numeric IDs for Matching, answer IDs for Numerical) but the extraction logic is identical: collect all `itemfeedback` elements whose ident ends in `_fb` and does not match the three special idents.

## Learnosity Mapping

All feedback maps to the `metadata` field of the Learnosity question object:

| QTI ident | Learnosity field |
|---|---|
| `correct_fb` | `metadata.correct_feedback` |
| `general_fb` | `metadata.general_feedback` |
| `general_incorrect_fb` | `metadata.incorrect_feedback` |
| `{anything}_fb` (multiple) | `metadata.distractor_rationale_response_level` (array, document order) |

Canvas exports per-answer `itemfeedback` elements in option order, so document order produces a correctly-aligned array without needing to cross-reference the `presentation` section.

The `metadata` key is only added to the question object when at least one feedback field is present.

## Data Flow

Current:
```
to_learnosity → add_learnosity_assets → return object
```

Proposed:
```
to_learnosity → add_learnosity_assets → extract_feedback → merge metadata → return object
```

No changes to `to_learnosity` in any question class. Feedback extraction is appended to the existing pipeline in the base class `convert` method.

## Implementation

### `extract_feedback` (new method on `QuizQuestion`)

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

### Updated `convert` (modified on `QuizQuestion`)

```ruby
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

### HTML Content

`.content` on the `mattext` Nokogiri node decodes XML entities and returns the HTML string (e.g. `<p>Feedback for Correct</p>`), consistent with how `extract_mattext` works for stimulus and option labels.

## Files Changed

- `lib/canvas_qti_to_learnosity_converter/questions/question.rb` — add `extract_feedback`, update `convert`

## Files Unchanged

All individual question type files (`multiple_choice.rb`, `matching.rb`, `numerical.rb`, etc.) require no changes.

## Testing

New tests added to the existing spec file using inline QTI strings:

1. **All four feedback types present** — verifies correct/general/incorrect feedback and distractor_rationale_response_level array
2. **Only general feedback** — verifies partial feedback sets work and no empty fields are included
3. **No feedback** — verifies no `metadata` key is added to the output
4. **Multiple per-answer feedbacks** — verifies distractor_rationale_response_level array is ordered correctly

Existing tests are unaffected since `extract_feedback` returns an empty hash when no `itemfeedback` elements exist.
