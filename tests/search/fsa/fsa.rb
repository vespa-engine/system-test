# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class Fsa < IndexedSearchTest

  def setup
    set_owner("geirst")
    deploy_app(SearchApp.new.sd(selfdir + "fsa.sd"))
    start
  end

  def test_fsa_binaries
    set_description("Test that vespa-makefsa, vespa-fsadump, and vespa-fsainfo are installed and working")
    vespa.adminserver.copy(selfdir + "list.txt", dirs.tmpdir)
    # text input format with meta info (-t)
    output = vespa.adminserver.execute("cd #{dirs.tmpdir} && vespa-makefsa -t -v list.txt list.fsa", :stderr => true)
    assert(Regexp.new("ignoring line 3, \"cc 32\" with missing meta info").match(output))
    assert(Regexp.new("ignoring unsorted line 5, \"dd\"").match(output))
    assert(Regexp.new("inserted 3/5 lines").match(output))
    output = vespa.adminserver.execute("cd #{dirs.tmpdir} && vespa-fsadump -t list.fsa")
    assert(Regexp.new("aa\t8\nbb\t\nee\t128").match(output))
    vespa.adminserver.execute("cd #{dirs.tmpdir} && vespa-fsainfo list.fsa")

    # text input format with numerical meta info (-n)
    output = vespa.adminserver.execute("cd #{dirs.tmpdir} && vespa-makefsa -n -v list.txt list.fsa", :stderr => true)
    assert(Regexp.new("ignoring line 3, \"cc 32\" with missing meta info").match(output))
    assert(Regexp.new("ignoring unsorted line 5, \"dd\"").match(output))
    assert(Regexp.new("inserted 3/5 lines").match(output))
    output = vespa.adminserver.execute("cd #{dirs.tmpdir} && vespa-fsadump -n list.fsa")
    assert(Regexp.new("aa\t8\nbb\t0\nee\t128").match(output))
    vespa.adminserver.execute("cd #{dirs.tmpdir} && vespa-fsainfo list.fsa")

    # test error situations
    output = vespa.adminserver.execute("cd #{dirs.tmpdir} && vespa-makefsa -v null.txt list.fsa", :exceptiononfailure => false, :stderr => true)
    assert(Regexp.new("Could not open file").match(output))
    output = vespa.adminserver.execute("cd #{dirs.tmpdir} && vespa-makefsa -v list.txt null/list.fsa", :exceptiononfailure => false, :stderr => true)
    assert(Regexp.new("Failed to write").match(output))
    output = vespa.adminserver.execute("cd #{dirs.tmpdir} && vespa-fsadump null.fsa", :exceptiononfailure => false, :stderr => true)
    assert(Regexp.new("Failed to open").match(output))
    output = vespa.adminserver.execute("cd #{dirs.tmpdir} && vespa-fsainfo null.fsa", :exceptiononfailure => false, :stderr => true)
    assert(Regexp.new("Failed to open").match(output))
  end

  def teardown
    stop
  end

end
