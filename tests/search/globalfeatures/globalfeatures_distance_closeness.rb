# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'


class GlobalFeaturesIndexed < IndexedStreamingSearchTest

  def setup
    set_owner("geirst")
    @id_field = "documentid"
  end

  #---------- distance and closeness ----------#
  def test_distance_and_closeness
    set_description("Test the distance and the closeness feature")
    deploy_app(SearchApp.new.sd(selfdir + "distance.sd"))
    start
#    vespa.adminserver.logctl("storagenode:visitor.instance.searchvisitor", "debug=on")
#    vespa.adminserver.logctl("storagenode:vsm.common.documenttypemapping", "debug=on")
#    vespa.adminserver.logctl("storagenode:vsm.fieldsearchspec", "debug=on")
#    vespa.adminserver.logctl("storagenode:features.distancefeature", "debug=on")
    feed_and_wait_for_docs("distance", 1, :file => selfdir + "distance.json")

    # location = 5,-5
    assert_distance(Math.sqrt(650),  10,  20);
    assert_distance(Math.sqrt(250),  10, -20);
    assert_distance(Math.sqrt(450), -10, -20);
    assert_distance(Math.sqrt(850), -10,  20);

    assert_closeness(1,   0)
    assert_closeness(0.5, 50)
    assert_closeness(0,   100)
  end

  def assert_distance(distance, x, y)
    query = "query=sddocname:distance&pos.xy=#{x}%3B#{y}"
    exp = {"distance(xy)" => distance}
    assert_features(exp, search(query).hit[0].field['summaryfeatures'], 1e-4)
  end

  def assert_closeness(closeness, distance)
    query = "query=sddocname:distance&pos.xy=#{distance + 5}%3B-5"
    exp = {"closeness(xy)" => closeness}
    assert_features(exp, search(query).hit[0].field['summaryfeatures'], 1e-4)
  end


  def teardown
    stop
  end

end
