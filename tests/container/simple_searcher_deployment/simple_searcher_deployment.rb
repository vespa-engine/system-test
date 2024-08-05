# Copyright Vespa.ai. All rights reserved.
require 'search_container_test'
require 'app_generator/container_app'

class SimpleSearcherDeployment < SearchContainerTest

  def setup
    set_owner("bratseth")
    set_description("Tests the application package produced in section 2 of search-container.html")
  end

  def test_simple_searcher_deployment
    add_bundle(selfdir+"SimpleSearcher.java")
    deploy_app(ContainerApp.new(false).
        container(Container.new.search(Searching.new.
                chain(Chain.new.add(
                    Searcher.new("com.yahoo.search.example.SimpleSearcher"))))))
    start

    system("vespa-get-config -n search-chains -i search/qrsclusters/default/qrserver.0")
    # One hit is added by our deployed searcher - nothing else is going on
    result = search("/search/?query=test&tracelevel=3")
    puts "Result from query=test:"
    puts result.xmldata
    assert_match(Regexp.new("Hello world"), result.xmldata,
                 "Could not find expected message in response.")
  end

  def teardown
    stop
  end

end
