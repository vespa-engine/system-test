# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'search_container_test'
require 'app_generator/container_app'

class V3BasicDocprocWithReason < SearchContainerTest

  def setup
    set_owner("valerijf")
    add_bundle(DOCPROC + "v3docprocs/WithReasonDocProc.java")

    deploy_app(
        ContainerApp.new.container(
            Container.new("default").
                search(Searching.new).
                docproc(DocumentProcessing.new.chain(
                            Chain.new("default").add(
                                DocumentProcessor.new("com.yahoo.vespatest.WithReasonDocProc"))))).
            search(SearchCluster.new("worst").sd(DOCPROC + "data/worst.sd"))
    )
    start
  end

  def test_v3_basicsearch_docproc
    feed_and_wait_for_docs("worst", 4, :file => DOCPROC + "data/worst-input.xml", :cluster => "worst")
    output = feedfile(selfdir+"worst.1.json", :cluster => "worst", :exceptiononfailure => false)
    assert_match(/Some detailed failure reason/, output)
    feed_and_wait_for_docs("worst", 4, :file => DOCPROC + "data/worst-input.json", :cluster => "worst")
  end

  def teardown
    stop
  end

end
