# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'json_document_writer'
require 'indexed_search_test'
require 'performance/fbench'
require 'pp'

class StreamingSearchPerformanceTest < PerformanceTest

    def setup
        set_owner('onorum')
        set_description('performance test for streaming search')
        @docPath = "#{selfdir}data/documents.json"
    end

    def test_streaming_search
        set_description('tesing query preformance of streaming search with prefix match on small documents')
        deploy("#{selfdir}app")
        start
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
        run_fbench(container, num_clients, 30, [parameter_filler('tag', "query length: #{num_chars}"),
                                        parameter_filler('legend', "query length: #{num_chars} chars, clients: #{num_clients}")])
    end
    
    def query_all_chars
        [1, 2, 4, 8, 16, 64].each { |clients| query_docs(clients, 4) }
	[2,3,4,5].each { |chars| query_docs(32, chars) }
    end

end
