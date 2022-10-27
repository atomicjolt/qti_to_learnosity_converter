
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "canvas_qti_to_learnosity_converter/version"

Gem::Specification.new do |spec|
  spec.name          = "canvas_qti_to_learnosity_converter"
  spec.version       = CanvasQtiToLearnosityConverter::VERSION
  spec.authors       = ["Atomic Jolt", "Nick Benoit"]
  spec.email         = ["support@atomicjolt.com"]

  spec.summary       = %q{Converts canvas qti to learnosity JSON}
  spec.homepage      = "https://github.com/atomicjolt/qti_to_learnosity_converter"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.3"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_dependency "nokogiri"
  spec.add_dependency "rubyzip"
end
