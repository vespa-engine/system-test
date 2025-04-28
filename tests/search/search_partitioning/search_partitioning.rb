# Copyright Vespa.ai. All rights reserved.
require 'document_set'
require 'indexed_only_search_test'
require 'pp'

class SearchPartitioning < IndexedOnlySearchTest

  def generate_feed(file_name, count)
    docs = DocumentSet.new

    for i in 0..(count - 1) do
      bitstring = ""
      for bit in 16.downto(0) do
        if (i & (1 << bit)) != 0 then
          bitstring += " bit#{bit}"
        end
      end

      doc = Document.new("id:test:test::doc#{i}")
      title = "title#{i}#{bitstring}"

      body = "body#{i}" + (bitstring * 100)

      doc.add_field("title", title)
      doc.add_field("body", body)

      docs.add(doc)
    end
    docs.write_json(file_name)
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
    feed_file = "#{dirs.tmpdir}/generated/feed.json"
    generate_feed(feed_file, 1024)
    start
    feed_and_wait_for_hitcount("title:title1", 1, :file => feed_file)
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
