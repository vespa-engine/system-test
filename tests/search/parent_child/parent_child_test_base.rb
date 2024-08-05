# Copyright Vespa.ai. All rights reserved.
require 'indexed_only_search_test'

class ParentChildTestBase < IndexedOnlySearchTest

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

