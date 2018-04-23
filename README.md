# CanvasQtiToLearnosityConverter

This gem is designed to facilitate the conversion of canvas quizzes exported as
qti 1.2, to the learnosity json format. It currently has support for converting
a single qti file, or converting an entire imscc export of qti quizzes. Be
aware that the CanvasQtiToLearnosityConverter makes assumptions about the
format of the qti that canvas exports as of 4/23/18, and will be sensitive
to spec compliant changes to the way that canvas exports qti.



## Installation

Add this line to your application's Gemfile:

```ruby
gem 'canvas_qti_to_learnosity_converter'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install canvas_qti_to_learnosity_converter

## Usage

#### Convert entire imscc export

```
# Convert All QTI Files in entire imscc
CanvasQtiToLearnosityConverter.convert_imscc_export(path)
# returns [
#  {
#    title: "Canvas Quiz Title",
#    ident: "canvas_qti_export_id",
#    items: [...converted_learnosity_questions... ]
#    More information on learnosity question format: https://docs.learnosity.com/analytics/data/endpoints/itembank_endpoints#setQuestions
#  }, ...
#]
```

#### Convert single qti string

```
# Convert single qti_string
CanvasQtiToLearnosityConverter.convert(qti_string)
# returns
#  {
#    title: "Canvas Quiz Title",
#    ident: "canvas_qti_export_id",
#    items: [...converted_learnosity_questions... ]
#    More information on learnosity question format: https://docs.learnosity.com/analytics/data/endpoints/itembank_endpoints#setQuestions
#  },
```

## Development

#### Specs

To run the tests
```rake spec```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
