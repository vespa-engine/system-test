# Copyright Vespa.ai. All rights reserved.
require 'document'
require 'document_set'
require 'indexed_streaming_search_test'

class LargeText < IndexedStreamingSearchTest

  def setup
    set_owner("hmusum")
    deploy_app(SearchApp.new.sd("#{selfdir}/test.sd"))
    start
  end

  def test_large_text
    arr = [ ]
    arr << time_feed(10000)
    arr << time_feed(20000)
    arr << time_feed(40000)
    arr << time_feed(80000)
    arr << time_feed(160000)
    arr << time_feed(320000)
    arr << time_feed(640000)
    arr << time_feed(1280000)
    puts "rate = " + arr.join(" ")
    feed_bad_file
  end

  def time_feed(num_tokens)
    doc = Document.new("id:ns:test::1")
    doc.add_field("my_str", (0..num_tokens - 1).map{ |i| "t#{i}" }.join(" "))

    docs = DocumentSet.new()
    docs.add(doc)

    file = "#{dirs.tmpdir}/input#{num_tokens}.json";
    docs.write_json(file)

    time = Time.now.getutc
    feed_and_wait_for_docs("test", 1, :file => file, 
                           :timeout => timeout_seconds)
    secs = Time.now.getutc - time
    rate = num_tokens / secs

    wait_for_hitcount("query=my_str:t" + (0).to_s, 1)
    wait_for_hitcount("query=my_str:t" + (num_tokens / 2).to_s, 1)
    wait_for_hitcount("query=my_str:t" + (num_tokens - 1).to_s, 1)

    puts "#{num_tokens} tokens => #{secs} secs, #{rate} rate"
    return rate
  end

  def feed_bad_file
    # no indexing happens for streaming
    return if is_streaming
    doc = Document.new("id:ns:test::1")
    doc.add_field("my_str", read_utf8_file_with_replacement('/bin/sh'))
    docs = DocumentSet.new()
    docs.add(doc)
    file = "#{dirs.tmpdir}/input-bad.json";
    docs.write_json(file)
    result = feed(:file => file)
    assert(result.include? 'Status 400')
    assert(result.include? 'classified as binary')
  end

  def read_utf8_file_with_replacement(file_path)
    content = File.read(file_path, encoding: 'UTF-8', invalid: :replace, undef: :replace, replace: "\u{FFFD}")
    content = content.encode('UTF-8', 'UTF-8', invalid: :replace, undef: :replace, replace: "\u{FFFD}")
    # Replace control characters (0x00-0x1F and 0x7F-0x9F) except whitespace (tab, newline, carriage return)
    content.gsub(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]/, "\u{FFFD}")
  end

  def create_json_from_file(file_path, doc_id)
    require 'json'
    content = read_utf8_file_with_replacement(file_path)
    {
      "id" => doc_id,
      "fields" => {
        "my_str" => content
      }
    }.to_json
  end

  def timeout_seconds
    return 900
  end

end
