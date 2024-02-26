# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class ConcreteDocs < IndexedStreamingSearchTest

  def setup
    set_owner('musum')
  end

  def test_concrete_docs
    add_bundle_dir(File.expand_path(selfdir + '/concretedocs2'), 'concretedocs2')
    add_bundle_dir(File.expand_path(selfdir + '/concretedocs'), 'concretedocs')
    deploy_app(SearchApp.new.
               sd(selfdir + 'concretedocs/vehicle.sd').
               sd(selfdir + 'concretedocs/ship.sd').
               sd(selfdir + 'concretedocs2/disease.sd').
               container(Container.new('default').
                         search(Searching.new).
                         documentapi(ContainerDocumentApi.new).
                         concretedoc(ConcreteDoc.new('vehicle')).
                         concretedoc(ConcreteDoc.new('ship')).
                         concretedoc(ConcreteDoc.new('disease').
                                     bundle('concretedocs2').
                                     klass('com.yahoo.concretedocs2.Disease')).
                         docproc(DocumentProcessing.new.
                                 chain(Chain.new('default').
                                       add(DocumentProcessor.new('concretedocs.ConcreteDocDocProc').
                                           bundle('concretedocs'))))))
    start
    feed_and_wait_for_docs('vehicle', 2, :file => selfdir+'vehicle.xml')
    feed_and_wait_for_docs('disease', 2, :file => selfdir+'disease.xml')

    # Check docs in index
    assert_hitcount('query=year:2013', 2)
    assert_hitcount('query=symptom:Paralysis', 2)

    # Check docs with GET
    port = Environment.instance.vespa_web_service_port
    doc = vespa.document_api_v1.get('id:vehicle:vehicle::0', :port => port)
    location = doc.fields['location']
    assert(location['lng'] == 0.000002)
    assert(location['lat'] == 0.000003)
    assert(doc.fields['year'] == 2013)
    assert(doc.fields['reg'] == 'FOO 1234')

    doc = vespa.document_api_v1.get('id:vehicle:vehicle::1', :port => port)
    location = doc.fields['location']
    assert(location['lng'] == 0.000002)
    assert(location['lat'] == 0.000003)
    assert(doc.fields['year'] == 2013)
    assert(doc.fields['reg'] == 'BAR 5678')

    doc = vespa.document_api_v1.get('id:disease:disease::0', :port => port)
    assert(doc.fields['symptom'] == 'Paralysis')

    doc = vespa.document_api_v1.get('id:disease:disease::1', :port => port)
    assert(doc.fields['symptom'] == 'Paralysis')
  end

  def teardown
    stop
  end

end

