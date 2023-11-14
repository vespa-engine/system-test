# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class ParentChildTestBase < IndexedSearchTest

  def is_grandparent_test
    @sub_test_dir == "grandparent"
  end

  def get_test_path(file_name)
    "#{selfdir}/#{@test_dir}/#{file_name}"
  end

  def get_sub_test_path(file_name)
    "#{selfdir}/#{@test_dir}/#{@sub_test_dir}/#{file_name}"
  end

end

