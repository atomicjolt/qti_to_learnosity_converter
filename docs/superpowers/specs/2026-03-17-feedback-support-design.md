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

The per-answer idents vary by question type (UUIDs for MCQ, numeric IDs for Matching/Numerical) but the extraction logic is identical: collect all `itemfeedback` elements whose ident ends in `_fb` and does not match the three special idents. Canvas exports them in option order, so document order produces a correctly-aligned array.

### Fill-in-Multiple-Blanks Edge Case

Fill-in-multiple-blanks questions in Canvas Classic can export per-blank feedback idents in QTI (e.g. `6491_fb`, `2293_fb`). In practice these elements are always empty in observed exports, and the code skips empty feedback via a nil/empty guard. If non-empty per-blank feedbacks do appear, they will be collected into `distractor_rationale_response_level` in document order, which may not perfectly align with Learnosity's expected structure for `clozetext` questions (which has multiple blanks). This is acceptable as a best-effort and can be revisited if real data surfaces the issue.

## Learnosity Mapping

All feedback maps to the `metadata` field of the Learnosity question object:

| QTI ident | Learnosity field |
|---|---|
| `correct_fb` | `metadata.correct_feedback` |
| `general_fb` | `metadata.general_feedback` |
| `general_incorrect_fb` | `metadata.incorrect_feedback` |
| `{anything}_fb` (multiple) | `metadata.distractor_rationale_response_level` (array, document order) |

The `metadata` key is only added to the question object when at least one feedback field is non-empty. No current question class returns `:metadata` from `to_learnosity`; the `||=` in `convert` is forward-compatible defensive coding for future subclasses. Note that `object` here is the inner question data hash returned by `to_learnosity`, not the outer widget wrapper hash (which has its own `:metadata` key in `convert.rb`). There is no conflict between these two levels.

`TextOnlyQuestion` (sharedpassage/feature type) goes through the same `convert` path. Since text-only items do not contain `itemfeedback` elements, `extract_feedback` returns `{}` and no metadata is added. No special handling is needed.

## Data Flow

Current:
```
to_learnosity → add_learnosity_assets → return (implicit return of add_learnosity_assets result)
```

Proposed:
```
to_learnosity → add_learnosity_assets → extract_feedback → merge metadata → return object (explicit)
```

All `add_learnosity_assets` implementations return their `learnosity` argument, so the current implicit return is equivalent to an explicit return of `object`. The proposed code makes this explicit, which is a minor improvement in clarity.

No changes to `to_learnosity` in any question class. Feedback extraction is appended to the existing pipeline in the base class `convert` method only.

## Implementation

### `extract_feedback` (new method on `QuizQuestion`)

`@xml` is a Nokogiri document wrapping the `item` element (consistent with how `extract_stimulus` uses `@xml.css("item > presentation > material > mattext")`). The `item > itemfeedback` direct-child selector is therefore correct.

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

The `mattext` node in QTI stores rich text as entity-escaped HTML (e.g. `&lt;p&gt;Feedback&lt;/p&gt;`). Nokogiri's `.content` decodes XML entities, returning the HTML markup string `<p>Feedback</p>`. This is the same behavior as `extract_mattext` used for stimulus and option labels throughout the codebase. Learnosity `metadata` feedback fields accept HTML strings.

## Files Changed

- `lib/canvas_qti_to_learnosity_converter/questions/question.rb` — add `extract_feedback`, update `convert`

## Files Unchanged

All individual question type files (`multiple_choice.rb`, `matching.rb`, `numerical.rb`, etc.) require no changes.

## Testing

New tests added inline (using QTI strings rather than fixture files, to isolate feedback behavior from unrelated question-conversion logic):

1. **All four feedback types present** — MCQ with correct/general/incorrect feedback and one per-answer feedback. Use a UUID-style ident ending in `_fb` (e.g. `abc123_fb`) for the per-answer element to match the MCQ ident pattern observed in Canvas exports. Asserts `result[:metadata]` equals expected hash including `distractor_rationale_response_level`.
2. **Only general feedback** — Asserts only `general_feedback` key is present; no empty fields included.
3. **No feedback** — Asserts `expect(result).not_to have_key(:metadata)`.
4. **Multiple per-answer feedbacks** — Two options with feedback, verifies array length and order.

Existing tests are unaffected since `extract_feedback` returns `{}` when no `itemfeedback` elements exist, leaving the output object unchanged.
