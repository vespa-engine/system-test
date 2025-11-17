# Copyright Vespa.ai. All rights reserved.

require 'search_container_test'
require 'app_generator/container_app'

class V3BasicDocprocWithReason < SearchContainerTest

  def get_default_log_check_levels
    # warnings are expected for this test:
    return [:error, :fatal]
  end

  def setup
    set_owner("hmusum")
    add_bundle(DOCPROC + "v3docprocs/WithReasonDocProc.java")

    deploy_app(
        ContainerApp.new.container(
            Container.new("default").
                search(Searching.new).
                docproc(DocumentProcessing.new.chain(
                            Chain.new("default").add(
                              DocumentProcessor.new("com.yahoo.vespatest.WithReasonDocProc")))).
                documentapi(ContainerDocumentApi.new)).
            search(SearchCluster.new("worst").sd(DOCPROC + "data/worst.sd"))
    )
    start
  end

  def test_v3_basicsearch_docproc
    feed_and_wait_for_docs("worst", 4, :file => DOCPROC + "data/worst-input.json", :cluster => "worst")
    output = feedfile(selfdir+"worst.1.json", :cluster => "worst", :exceptiononfailure => false, :stderr => true)
    assert_match(/Some detailed failure reason/, output)
    feed_and_wait_for_docs("worst", 4, :file => DOCPROC + "data/worst-input.json", :cluster => "worst")
  end

end
