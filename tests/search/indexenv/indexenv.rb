# Copyright Vespa.ai. All rights reserved.
require 'rubygems'
require 'json'
require 'indexed_only_search_test'

class IndexEnv < IndexedOnlySearchTest

  def setup
    set_owner("havardpe")
  end

  def check_features(features, map)
    json = features
    wanted = {
      "fieldInfo.indexCnt" => 13,
      "fieldInfo.attrCnt" => 3,

      "fieldInfo(alone).type" => 1,
      "fieldInfo(attr1).type" => 2,
      "fieldInfo(attr2).type" => 2,
      "fieldInfo(both).type" => 1,    # index not attribute
      "fieldInfo(default1).type" => 1,
      "fieldInfo(default3).type" => 1,
      "fieldInfo(filter).type" => 1,
      "fieldInfo(int1).type" => 2,    # attribute not index
      "fieldInfo(uri1).type" => 1,
      "fieldInfo(uri1.fragment).type" => 1,
      "fieldInfo(uri1.host).type" => 1,
      "fieldInfo(uri1.hostname).type" => 1,
      "fieldInfo(uri1.path).type" => 1,
      "fieldInfo(uri1.port).type" => 1,
      "fieldInfo(uri1.query).type" => 1,
      "fieldInfo(uri1.scheme).type" => 1,

      "fieldInfo(alone).filter" => 0,
      "fieldInfo(attr1).filter" => 0,
      "fieldInfo(attr2).filter" => 0,
      "fieldInfo(both).filter" => 0,
      "fieldInfo(default1).filter" => 0,
      "fieldInfo(default3).filter" => 0,
      "fieldInfo(filter).filter" => 1,
      "fieldInfo(int1).filter" => 0,
      "fieldInfo(uri1).filter" => 0,
      "fieldInfo(uri1.fragment).filter" => 0,
      "fieldInfo(uri1.host).filter" => 0,
      "fieldInfo(uri1.hostname).filter" => 0,
      "fieldInfo(uri1.path).filter" => 0,
      "fieldInfo(uri1.port).filter" => 0,
      "fieldInfo(uri1.query).filter" => 0,
      "fieldInfo(uri1.scheme).filter" => 0,

      "fieldInfo(alone).search" => 0,
      "fieldInfo(attr1).search" => 0,
      "fieldInfo(attr2).search" => 0,
      "fieldInfo(both).search" => 0,
      "fieldInfo(default1).search" => 0,
      "fieldInfo(default3).search" => 0,
      "fieldInfo(filter).search" => 0,
      "fieldInfo(int1).search" => 0,
      "fieldInfo(uri1).search" => 0,
      "fieldInfo(uri1.fragment).search" => 0,
      "fieldInfo(uri1.host).search" => 0,
      "fieldInfo(uri1.hostname).search" => 0,
      "fieldInfo(uri1.path).search" => 0,
      "fieldInfo(uri1.port).search" => 0,
      "fieldInfo(uri1.query).search" => 0,
      "fieldInfo(uri1.scheme).search" => 0,

      "fieldInfo(alone).hit" => 0,
      "fieldInfo(attr1).hit" => 0,
      "fieldInfo(attr2).hit" => 0,
      "fieldInfo(both).hit" => 0,
      "fieldInfo(default1).hit" => 0,
      "fieldInfo(default3).hit" => 0,
      "fieldInfo(filter).hit" => 0,
      "fieldInfo(int1).hit" => 0,
      "fieldInfo(uri1).hit" => 0,
      "fieldInfo(uri1.fragment).hit" => 0,
      "fieldInfo(uri1.host).hit" => 0,
      "fieldInfo(uri1.hostname).hit" => 0,
      "fieldInfo(uri1.path).hit" => 0,
      "fieldInfo(uri1.port).hit" => 0,
      "fieldInfo(uri1.query).hit" => 0,
      "fieldInfo(uri1.scheme).hit" => 0
    }
    map.each_pair { |key, value| wanted[key] = value }
    wanted.each_pair { |key, value|
      assert_features({key => value}, json)
    }
  end

  def test_profiles
    deploy_app(SearchApp.new.sd(selfdir + "test.sd"))
    start
    feed_and_wait_for_docs("test", 1, :file => selfdir + "doc.json")
    assert_hitcount("query=test", 1)

    # uri1
    result = search("query=uri1:vg&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    check_features(features, { "fieldInfo(uri1).search" => 1,
                               "fieldInfo(uri1).hit" => 1 } )

    # uri1.host
    result = search("query=uri1.host:vg&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    check_features(features, { "fieldInfo(uri1.host).search" => 1,
                               "fieldInfo(uri1.host).hit" => 1 } )

    # int1
    result = search("query=int1:42&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    check_features(features, { "fieldInfo(int1).search" => 1,
                               "fieldInfo(int1).hit" => 1 } )


    # only default1
    result = search("query=default1:default1&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    check_features(features, { "fieldInfo(default1).search" => 1,
                               "fieldInfo(default1).hit" => 1 } )

    # only default3
    result = search("query=default3:default3&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    check_features(features, { "fieldInfo(default3).search" => 1,
                               "fieldInfo(default3).hit" => 1 } )

    # alone
    result = search("query=alone:alone&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    check_features(features, { "fieldInfo(alone).search" => 1,
                               "fieldInfo(alone).hit" => 1 } )

    # both
    result = search("query=both:both&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    check_features(features, { "fieldInfo(both).search" => 1,
                               "fieldInfo(both).hit" => 1 } )

    # attr1
    result = search("query=attr1:attr1&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    check_features(features, { "fieldInfo(attr1).search" => 1,
                               "fieldInfo(attr1).hit" => 1 } )

    # attr2
    result = search("query=attr2:2&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    check_features(features, { "fieldInfo(attr2).search" => 1,
                               "fieldInfo(attr2).hit" => 1 } )

    # default:default1
    result = search("query=default1&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    check_features(features, { "fieldInfo(default1).search" => 1,
                               "fieldInfo(default3).search" => 1,
                               "fieldInfo(default1).hit" => 1 } )

    # default:default3
    result = search("query=default3&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    check_features(features, { "fieldInfo(default1).search" => 1,
                               "fieldInfo(default3).search" => 1,
                               "fieldInfo(default3).hit" => 1 } )

    # default:test
    result = search("query=test&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    check_features(features, { "fieldInfo(default1).search" => 1,
                               "fieldInfo(default3).search" => 1,
                               "fieldInfo(default1).hit" => 1,
                               "fieldInfo(default3).hit" => 1 } )

    # test filter terms
    result = search("query=filter:filter&parallel&rankfeatures")
    assert(result.hit.size == 1)
    features = result.hit[0].field["rankfeatures"]
    check_features(features, { "fieldInfo(filter).search" => 1,
                               "fieldInfo(filter).hit" => 1 } )

  end

  def teardown
    stop
  end

end
