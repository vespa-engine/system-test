# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'search_container_test'

class SearcherOrder < SearchContainerTest
    def setup
        set_owner("arnej")
        set_description("Tests redeployment of same application, only changing order of searchers.")
        @valgrind=false
    end

    def timeout_seconds
        return 1800
    end

    def test_searcher_ordering
        add_bundle_dir(File.expand_path(selfdir) + "/that_searcher", "com.yahoo.testvespa.ThatSearcher")
        add_bundle_dir(File.expand_path(selfdir) + "/this_searcher", "com.yahoo.vespatest.ThisSearcher")
        deploy(selfdir + "app1", SEARCH_DATA+"music.sd")
        start
        wait_for_hitcount("query=test", 0)  # Just wait for the Qrs to be up
        query =  "/search/?searchChain=nalle"
        result = search(query)
        assert_match("ThisSearcher, current number of concrete hits: 1", result.xmldata)
        assert_match("ThatSearcher, current number of concrete hits: 0", result.xmldata)
        deploy(selfdir + "app2", SEARCH_DATA+"music.sd")
        oldout = Regexp.new("ThisSearcher, current number of concrete hits: 1")
        (1..90).each do |tryno|
            result = search(query)
            if oldout.match(result.xmldata)
                puts "try #{tryno} waiting for reconfiguration to complete"
                sleep 1
            else
                puts "try #{tryno} reconfiguration complete"
            end
        end
        result = search(query)
        assert_match("ThisSearcher, current number of concrete hits: 0", result.xmldata)
        assert_match("ThatSearcher, current number of concrete hits: 1", result.xmldata)
    end

    def test_searcher_orderflip
        add_bundle_dir(File.expand_path(selfdir) + "/that_searcher", "com.yahoo.testvespa.ThatSearcher")
        add_bundle_dir(File.expand_path(selfdir) + "/this_searcher", "com.yahoo.vespatest.ThisSearcher")
        deploy(selfdir + "app1", SEARCH_DATA+"music.sd")
        start
        wait_for_hitcount("query=test", 0)  # Just wait for the Qrs to be up
        query =  "/search/?searchChain=nalle"
        result = search(query)
        assert_match("ThisSearcher, current number of concrete hits: 1", result.xmldata)
        assert_match("ThatSearcher, current number of concrete hits: 0", result.xmldata)
        deploy(selfdir + "app3", SEARCH_DATA+"music.sd")
        oldout = Regexp.new("ThisSearcher, current number of concrete hits: 1")
        (1..90).each do |tryno|
            result = search(query)
            if oldout.match(result.xmldata)
                puts "try #{tryno} waiting for reconfiguration to complete"
                sleep 1
            end
        end
        result = search(query)
        assert_match("ThisSearcher, current number of concrete hits: 0", result.xmldata)
        assert_match("ThatSearcher, current number of concrete hits: 1", result.xmldata)
    end

    def test_searcher_in_provider_noorder
        add_bundle_dir(File.expand_path(selfdir) + "/end_searcher", "com.yahoo.vespatest.EndSearcher")
        deploy(selfdir + "app4", SEARCH_DATA+"music.sd")
        start
        wait_for_hitcount("?query=test", 0)  # Just wait for the Qrs to be up
        result = search("/search/?query=foobar")
        assert_match("EndSearcher: 42", result.xmldata)
    end

    def teardown
        stop
    end
end
