# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class GroupingPagination < IndexedStreamingSearchTest

  SAVE_RESULT = false

  def setup
    set_owner("bjorncs")
    deploy_app(SearchApp.new.sd("#{selfdir}/song.sd"))
    start
  end

  def test_grouping_pagination
    feed_and_wait_for_docs("song", 159, :file => "#{selfdir}/docs.json")
    assert_continue([],
                    "#{selfdir}/res-empty.xml")
    assert_continue(["BGAAABEBEBC"],
                    "#{selfdir}/res-artist2-album11-song11.xml")
    assert_continue(["BKAAAAABGBEBC"],
                    "#{selfdir}/res-artist1-album21-song11.xml")
    assert_continue(["BOAAAAAAABIBEBC"],
                    "#{selfdir}/res-artist1-album11-song21.xml")
    assert_continue(["BKAAABCABGBEBC"],
                    "#{selfdir}/res-artist1-album12-song11.xml")
    assert_continue(["BOAAABCAAABIBEBC"],
                    "#{selfdir}/res-artist1-album11-song12.xml")
    assert_continue(["BKAAAAABGBEBC", "BOAAABCAAABIBEBC"],
                    "#{selfdir}/res-artist1-album21-song12.xml")
    assert_continue(["BKAAABCABGBEBC", "BOAAAAAAABIBEBC"],
                    "#{selfdir}/res-artist1-album12-song21.xml")
  end

  def assert_continue(continue, file)
    grouping = "all%28group%28artist%29+order%28min%28year%29%29+max%282%29+" +
               "each%28group%28album%29+order%28min%28year%29%29+max%282%29+" +
               "each%28max%282%29+" +
               "each%28output%28summary%28%29%29%29%29%29%29"
    my_assert_query("/search/?query=sddocname:song&hits=0&select=#{grouping}&continue=" + continue.join('+'), file)
    my_assert_query("/search/?hits=0&yql=select%20%2A%20from%20sources%20%2A%20where%20sddocname%20contains%20%27song%27%20%7C%20" +
                    "[{ 'continuations':['" + continue.join("','") + "'] }]#{grouping}%3B", file)
  end

  def my_assert_query(query, file)
    puts(query)
    if (SAVE_RESULT && !check_xml_result(query, file)) then
      File.open(file, "w") { |f| f.write(search(query).xmldata) }
    end
    assert_xml_result_with_timeout(4.0, query, file)
  end

  def teardown
    stop
  end

end
