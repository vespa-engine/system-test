# Copyright 2020 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'

class InheritedStruct < IndexedSearchTest

  def setup
    set_owner("balder")
    set_description("Test that structs can be used in inherited types.")
  end

  # Multiple clusters inherit from same base sd
  def ignore_test_structs_are_inherited
    #add_bundle_dir(File.expand_path(selfdir + "/concretedocs"), "concretedocs")
    deploy(selfdir + "app", [selfdir + "concretedocs/base.sd", selfdir + "concretedocs/usebase.sd"])
    start
    feed(:file => selfdir + "docs.json")
    assert_hitcount("query=sddocname:usebase", 1)
  end

  def teardown
    stop
  end

end
