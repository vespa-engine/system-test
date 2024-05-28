# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'document_set'
require 'environment'
require 'indexed_streaming_search_test'

class SlowQuery < IndexedStreamingSearchTest

  HTTP_CONTENT_LENGTH = 20

  class SlowStream
    def initialize
      @chars_left = HTTP_CONTENT_LENGTH
    end

    def read(size, out)
      if eof
        nil
      else
        sleep 1
        @chars_left = @chars_left - 1
        out << 'a'
        1
      end
    end

    def eof
      @chars_left <= 0
    end
  end

  def setup
    set_owner("arnej")
    deploy_app(SearchApp.new.sd(selfdir+"simple.sd"))
    @feed_file = dirs.tmpdir + 'feed.json'
    start
  end

  def test_slow_query
    generate_documents(@feed_file)
    feed(:file => @feed_file)

    wait_for_hitcount("sddocname:simple", 400)
    assert_hitcount("foobar", 400)

    num_queries = 3
    puts "Doing #{num_queries} queries using misbehaving client."
    qrserver = vespa.container.values.first
    num_queries.times do
      hname = qrserver.name
      sport = qrserver.http_port
      https_client.with_https_connection(hname, sport, '/search/', query: 'query=foobar&hits=400&timeout=1.0s') do |connection, uri|
        request = Net::HTTP::Post.new(uri, {'Content-Length' => HTTP_CONTENT_LENGTH.to_s})
        request.body_stream = SlowStream.new
        connection.request(request) do |response|
          puts "Response of length #{response.read_body.length} received"
        end
      puts "Request succeeded and connection closed"
      end
    end

    # Now to try and make sure the messages propagate to the vespa log file
    sleep 10
    qrserver.stop
    # numlogs = assert_log_matches(/container.*Slow execution/, 20)
    # puts "GOT log matches: #{numlogs} messages about Slow execution"

    i = 0
    query_time_sum = 0.0
    10.times do
        i += 1
        entry = qrserver.execute("zstdgrep -h foobar #{Environment.instance.vespa_home}/logs/vespa/access/JsonAccessLog.default.* | head -#{i+1} | tail -1").chomp
        assert(entry && entry != "", "Could not find foobar in JsonAccessLog.default")
        puts "GOT entry #{entry}"
        j = JSON.parse entry
        query_time = j['duration']
        assert(query_time, "Could not find query time in log entry: #{j}")
        puts "GOT Query time from access log: #{query_time}"
        query_time_sum += query_time.to_f
    end
    query_time_avg = query_time_sum / i
    puts "GOT Query time from access log: #{query_time_avg}"
    assert(query_time_avg.to_f <= 11.0, "Too long query time")
  end

  def generate_documents(feed_file)
    docs = DocumentSet.new
    (0..399).each { | i |
      doc = Document.new("simple", "id:test:simple::#{i}")
      doc.add_field("title", "foobar #{i} foobar")
      description = ""
      (0..677).each { | count |
        description += "foobar #{1234567 - count} "
      }
      docs.add(doc)
    }
    docs.write_json(feed_file)
  end

  def teardown
    stop
  end

end
