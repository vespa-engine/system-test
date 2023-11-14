# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class PageTemplatesResolvers < SearchContainerTest

  def setup
    set_owner("bratseth")
    set_description("Tests page template resolver plugins")
  end

  # Tests using various page template resolver plugins which each chooses a
  # different mock source referenced in the page template
  def test_pagetemplates_resolvers
    add_bundle(selfdir+"MockProvider.java")   # Searcher - Returns hits with the source name it is invoked as
    add_bundle(selfdir+"FirstChoiceResolver.java") # "Resolver - Always chooses the first option"
    add_bundle(selfdir+"MiddleChoiceResolver.java") # "Resolver - Always chooses the middle option"
    deploy(selfdir + "app")
    start

    q="/?query=test&page.id=sourceChoice&presentation.format=page"

    wait_for_atleast_hitcount("query=test",0)
    # save_result(q + "&page.resolver=test.first",selfdir + "sourceChoiceResultFirst.xml")
    # save_result(q + "&page.resolver=test.middle",selfdir + "sourceChoiceResultMiddle.xml")
    # save_result(q + "&page.resolver=native.deterministic",selfdir + "sourceChoiceResultLast.xml")

    assert_xml_result(q + "&page.resolver=test.first",selfdir + "sourceChoiceResultFirst.xml")
    assert_xml_result(q + "&page.resolver=test.middle",selfdir + "sourceChoiceResultMiddle.xml")
    assert_xml_result(q + "&page.resolver=native.deterministic",selfdir + "sourceChoiceResultLast.xml")
   end

  def teardown
    stop
  end

end
