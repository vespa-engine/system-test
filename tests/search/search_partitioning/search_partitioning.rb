# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_search_test'
require 'pp'

class SearchPartitioning < IndexedSearchTest

  def generate_feed(file_name, count)
    file = File.new("#{dirs.tmpdir}/generated/#{file_name}", "w")
    for i in 0..(count - 1) do
      bitstring = ""
      for bit in 16.downto(0) do
        if (i & (1 << bit)) != 0 then
          bitstring += " bit#{bit}"
        end
      end

      docid = "id:test:test::doc#{i}"
      title = "title#{i}#{bitstring}"
      body = "body#{i}" + (bitstring * 100)

      document = "<document documenttype=\"test\" documentid=\"#{docid}\">\n"
      document += "  <title>#{title}</title>\n"
      document += "  <body>#{body}</body>\n"
      document += "</document>\n"

      file.puts(document)
    end
    file.close
  end

  def print_metrics
    metrics = vespa.search["search"].first.get_total_metrics
    puts("Metrics for default rank profile:")
    pp metrics.extract(/[.]matching[.]default[.]/)
  end

  def setup
    set_owner("havardpe")
    set_description("Test using multiple threads for matching")
    @valgrind = false
    @valgrind_opt = nil

    begin
      Dir::mkdir("#{dirs.tmpdir}/generated")
    rescue
    end
  end

  def run_test
    generate_feed("feed.xml", 1024)
    start
    feed_and_wait_for_hitcount("title:title1", 1,
                               :file => dirs.tmpdir + "generated/feed.xml")
    assert_hitcount("title:bit1&type=all", 512);
    assert_hitcount("title:bit2+title:bit4&type=all", 256);
    print_metrics
  end

  def test_one_thread
    deploy_with_threads_per_search(1)
    run_test
  end

  def test_four_threads
    deploy_with_threads_per_search(4)
    run_test
  end

  def deploy_with_threads_per_search(count)
    deploy_app(SearchApp.new.sd(selfdir+"test.sd").threads_per_search(count))
  end

  def teardown
    stop
    @valgrind = false
    @valgrind_opt = nil
  end

end
