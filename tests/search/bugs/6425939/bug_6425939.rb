# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_test'

class Bug6425939Test < SearchTest

  def setup
    set_owner('vekterli')
  end

  def teardown
    stop
  end

  def test_java_document_deserialization_error
    deploy(selfdir + 'conf')
    start

    feed(:file => selfdir + 'singledoc.xml')

    vespa.adminserver.execute('vespa-visit')
  end

end
