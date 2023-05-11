# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_streaming_search_test'

class Addnewfield < IndexedStreamingSearchTest

  def setup
    set_owner("musum")
    set_description("Test that adding a new field to the searchdefinition works without reindexing "+
                    "data. The field creates a new index and is also added to the document summary.")
  end

  def test_addnewfield
    deploy_app(SearchApp.new.sd(rename_and_use_sd_file(selfdir+"simple-music.sd", "music.sd")))
    start

    puts "Summary ids in summary config after first deploy"
    print_summary_config_ids

    sddoc_query = "query=sddocname:music&nocache"

    feed_and_wait_for_hitcount(sddoc_query, 15,  :file => selfdir+"music.xml")

    fields = ["title", "popularity", "documentid"]

    assert_result(sddoc_query, selfdir+"result.10.json", nil, fields)

    # deploy config with extra document field
    deploy_output = deploy_app(SearchApp.new.sd(rename_and_use_sd_file(selfdir+"wnf-music.sd", "music.sd")))
    wait_for_application(vespa.container.values.first, deploy_output)
    wait_for_reconfig(get_generation(deploy_output).to_i, 600, true)

    ### Pragmatic sleep to wait for config propagation as streaming search does ad-hoc config subscription.
    ### The proper solution is to wire this in to set of configs monitored in proton.
    sleep(5) if is_streaming

    puts "Summary ids in summary config after second deploy"
    print_summary_config_ids

    wait_for_hitcount(sddoc_query, 15)

    # getting old results should still work:
    assert_result(sddoc_query, selfdir + "result.10.proton.json", nil, fields)

    # add 1 document, this should force summary.cf merging:
    feed_and_wait_for_hitcount(sddoc_query, 16, :file => selfdir+"wnf.1.xml")

    # we should be able to search the new field
    wait_for_hitcount("query=newfield:field&nocache", 1)

    # we should now see the new field in summary (in the new document only)
    assert_result(sddoc_query + "&hits=99", selfdir + "result.16.proton.json", nil, fields.push("newfield"))
  end

  def print_summary_config_ids
    config = getvespaconfig("vespa.config.search.summary", "search/search/cluster.search/music")
    config["classes"].each do |summaryclass|
      puts summaryclass["id"]
    end
  end

  def teardown
    stop
  end

end
