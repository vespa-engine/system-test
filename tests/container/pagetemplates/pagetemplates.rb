# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'

class PageTemplates < SearchContainerTest

  def setup
    set_owner("bratseth")
    set_description("Tests page templates.")
  end

  # This tests result reorganization in the QRS using page templates.
  # Several instances of a simple mock backend is used to provide data.
  # TODO: Rewrite to use json comparison
  def test_pagetemplates
    add_bundle(selfdir+"SourceSelector.java"); # Not used now, but may be useful later
    add_bundle(selfdir+"MockProvider.java");   # Returns hits with the source name it is invoked as
    deploy(selfdir + "app")
    start

    q="/?query=test&page.resolver=native.deterministic&presentation.format=page"

    wait_for_atleast_hitcount("query=test",0)
    # save_result(q + "&page.id=anySource",selfdir + "anySourceResult.xml")
    # save_result(q + "&page.id=blend",selfdir + "blendResult.xml")
    # save_result(q + "&page.id=map",selfdir + "mapResult.xml")
    # save_result(q + "&page.id=rendererChoice",selfdir + "rendererChoiceResult.xml")
    # save_result(q + "&page.id=sections",selfdir + "sectionsResult.xml")
    # save_result(q + "&page.id=sourceChoice",selfdir + "sourceChoiceResult.xml")

    assert_xml_result(q + "&page.id=anySource",selfdir + "anySourceResult.xml")
    assert_xml_result(q + "&page.id=blend",selfdir + "blendResult.xml")
    assert_xml_result(q + "&page.id=map",selfdir + "mapResult.xml")
    assert_xml_result(q + "&page.id=rendererChoice",selfdir + "rendererChoiceResult.xml")
    assert_xml_result(q + "&page.id=sections",selfdir + "sectionsResult.xml")
    assert_xml_result(q + "&page.id=sourceChoice",selfdir + "sourceChoiceResult.xml")
  end

  def teardown
    stop
  end

end
