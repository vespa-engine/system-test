# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class SameNameStructs < IndexedSearchTest

  def setup
    set_owner('arnej')
    set_description('Test that struct types can have same name in different sd files.')
  end

  # Use structs (and document) with same name
  def test_struct_types_with_same_name
    deploy_app(SearchApp.new.
               sd(selfdir + 'schemas/foo.sd').
               sd(selfdir + 'schemas/foobar.sd').
               sd(selfdir + 'schemas/mystruct.sd').
               sd(selfdir + 'schemas/bar.sd'))
    start
    feed(:file => selfdir + 'docs.json')
    vespa.adminserver.execute('vespa-visit')
    assert_hitcount('query=sddocname:foo', 1)
    assert_hitcount('query=sddocname:mystruct', 1)
    assert_hitcount('query=sddocname:bar', 1)
    assert_hitcount('query=sddocname:foobar', 1)
    assert_hitcount('query=f2.age:20', 1)
    assert_hitcount('query=f2.age:30', 1)
    assert_hitcount('query=f2.name:infoo', 1)
    assert_hitcount('query=f2.name:"in foo too"', 1)
    assert_hitcount('query=f4:my', 1)
    assert_hitcount('query=f5.key:one', 1)
    assert_hitcount('query=f5.key:two', 1)

    assert_hitcount('/search/?yql=select * from sources * where f5.value.something contains "some thing"', 1)
    assert_hitcount('/search/?yql=select * from sources * where f5.value.something contains "the Answer to Everything"', 1)
    assert_hitcount('/search/?yql=select * from sources * where f5.value.number = 90', 1)
    assert_hitcount('/search/?yql=select * from sources * where f5.value.number = 42', 1)

    assert_hitcount('query=f5.value.number:90', 1)
    assert_hitcount('query=f5.value.number:42', 1)
    assert_hitcount('query=f5.value.something:"some thing"', 1)
    assert_hitcount('query=f5.value.something:"the answer to everything"', 1)
  end

  def teardown
    stop
  end

end
