# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'docproc_test'
require 'environment'

class AnnotationsDocproc < DocprocTest

  def setup
    set_owner("gjoranv")
    add_bundle(selfdir + "Annotator.java");
    add_bundle(selfdir + "Consumer.java");
    deploy(DOCPROC + "annotationsetup-1x1")
    start
  end

  def test_annotations
    doc = Document.new("article", "id:article:article::boringarticle:longarticle").
      add_field("title", "Very long article").
      add_field("content", "Very interesting content")
    vespa.document_api_v1.put(doc, :port => Environment.instance.vespa_web_service_port, :route => "container/chain.annotatorchain consumer/chain.consumerchain")
  end

  def teardown
    stop
  end

end
