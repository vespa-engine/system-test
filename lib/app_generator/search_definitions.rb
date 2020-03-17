# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class SearchDefinitions
  def initialize(sd_files)
    @sd_files = sd_files
  end

  def to_xml(indent)
    XmlHelper.new(indent).
      tag("searchdefinitions").
        list_do(@sd_files) { |helper, sd|
          helper.tag("searchdefinition", :name => File.basename(sd.file_name, '.sd')).
            close_tag }.to_s
  end
end
