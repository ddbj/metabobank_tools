# frozen_string_literal: true

require_relative 'metabobank_tools/mb-method'
require_relative 'metabobank_tools/version'

module MetabobankTools
  def self.conf_path
    File.expand_path('../conf', __dir__)
  end
end
