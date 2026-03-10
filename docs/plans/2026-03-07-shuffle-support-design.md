# Shuffle Support Design

## Goal

Read the Canvas QTI shuffle attribute for each question type and pass it through to the Learnosity output as `shuffle_options`, rather than hardcoding or omitting it.

## QTI Encoding by Question Type

| Question type | QTI attribute location |
|---|---|
| Multiple Choice / Multiple Answers | `<render_choice shuffle="Yes|No">` |
| Ordering | `<ims_render_object shuffle="Yes|No">` |
| Matching | `<render_choice>` — attribute not present in Canvas QTI exports |

## Approach

Per-class extraction (Approach A): each question class reads its own shuffle attribute directly in `to_learnosity`. No shared abstraction needed since each type uses a different XML path.

## Changes by File

### `multiple_choice.rb` — `MultipleChoiceQuestion` and `MultipleAnswersQuestion`

Read `render_choice @shuffle` in `to_learnosity` for both classes:

```ruby
shuffle = @xml.css("item > presentation > response_lid > render_choice").first&.attribute("shuffle")&.value
shuffle_options: shuffle == "Yes"
```

Default: `false` when attribute is absent.

### `ordering.rb` — `OrderingQuestion`

Read `ims_render_object @shuffle` in `to_learnosity`:

```ruby
shuffle = @xml.css("ims_render_object").first&.attribute("shuffle")&.value
shuffle_options: shuffle == "Yes"
```

Default: `false` when attribute is absent.

### `matching.rb` — `MatchingQuestion`

Replace hardcoded `shuffle_options: true` with a read of `render_choice @shuffle` (first occurrence, since all dropdowns share the same options list):

```ruby
shuffle = @xml.css("item > presentation > response_lid > render_choice").first&.attribute("shuffle")&.value
shuffle_options: shuffle == "Yes"
```

Default: `false` when attribute is absent (Canvas does not encode this in QTI exports).

## Tests

- Update existing MCQ/matching/ordering fixtures to include `shuffle="Yes"` or `shuffle="No"` where appropriate.
- Assert `shuffle_options: true` when `shuffle="Yes"`.
- Assert `shuffle_options: false` when `shuffle="No"` or attribute is absent.
