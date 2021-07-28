# Copyright Verizon Media. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'json_document_writer'
require 'indexed_search_test'
require 'performance/fbench'
require 'pp'

class StreamingSearchTest < PerformanceTest


    def setup
        set_owner('onorum')
        set_description('preformance test for streaming search')
        @docPath = "#{selfdir}data/documents.json"
        start
    end


    def test_streaming_search
        set_description('tesing query preformance of streaming search with prefix match on small documents')
        deploy("#{selfdir}app")
        feed(:file => @docPath)
        warm_up
        query_all_chars
    end

    def warm_up
        @queryfile = "#{selfdir}data/2_char_queries.txt"
        container = (vespa.qrserver['0'] or vespa.container.values.first)
        run_fbench(container, 2, 20, [parameter_filler('tag', 'ignore'),
                                        parameter_filler('legend', 'ignore1')])
    end

    def query_docs(num_clients, num_chars)
        @queryfile = "#{selfdir}data/#{num_chars}_char_queries.txt"
        container = (vespa.qrserver['0'] or vespa.container.values.first)
        run_fbench(container, num_clients, 30, [parameter_filler('tag', "query with lenght: #{num_chars} chars"),
                                        parameter_filler('legend', 'getviapi')])
    end

    
    def query_num_chars(num_chars)
        [1, 2, 4, 8, 16, 32, 64].each { |clients| query_docs(clients, num_chars) }
    end

    def query_all_chars
        query_num_chars(2)
        query_num_chars(3)
        query_num_chars(4)
        query_num_chars(5)
    end

end