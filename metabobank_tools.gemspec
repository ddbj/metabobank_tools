# frozen_string_literal: true

require_relative "lib/metabobank_tools/version"

Gem::Specification.new do |spec|
  spec.name = 'metabobank_tools'
  spec.version = MetabobankTools::VERSION
  spec.authors = ['Bioinformation and DDBJ Center']

  spec.summary = 'Metabobank tools'
  spec.homepage = 'https://github.com/ddbj/metabobank_tools'
  spec.license  = 'Apache-2.0'

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "csv"
end
