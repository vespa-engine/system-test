# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'rubygems'
require 'json'
require 'indexed_streaming_search_test'

class DistanceToPath < IndexedStreamingSearchTest

  def setup
    set_owner("yngve")
    set_description("Test the distance-to-path feature.")
    deploy_app(SearchApp.new.sd("#{selfdir}/local.sd"))
    start
  end

  def test_basics
    feed_and_wait_for_docs("local", 2, :file => "#{selfdir}/basics.xml")
    assert_hitcount("query=sddocname:local", 2)
    assert_hitcount("query=one", 1)
    assert_hitcount("query=two", 1)

    assert_distance("one", "a", 6400000000, 1)
    assert_distance("one", "(", 6400000000, 1)
    assert_distance("one", "(a", 6400000000, 1)
    assert_distance("one", "(a)", 6400000000, 1)
    assert_distance("one", "(-1)", 6400000000, 1)
    assert_distance("one", "(-1,1)", 6400000000, 1)
    assert_distance("one", "(-1,1,1)", 6400000000, 1)
    assert_distance("one", "(-1 1 1 1)", 6400000000, 1)
    assert_distance("one", "(-1,1,1,1)", 1, 0.5)

    assert_distance("one", "(0,0,0,0)", 0, 0)
    assert_distance("one", "(0,0,0,0,0,0)", 0, 0)
    assert_distance("one", "(0,1,0,1)", 1, 0)
    assert_distance("one", "(0,1,0,1,0,1)", 1, 0)

    assert_distance("one", "(-1,1,1,-1)", 0, 0.5)
    assert_distance("one", "(-2,2,2,-2)", 0, 0.5)
    assert_distance("one", "(-1,1,3,-3)", 0, 0.25)

    assert_distance("one", "(1,0,2,0)", 1, 0)
    assert_distance("one", "(0,1,0,2)", 1, 0)
    assert_distance("one", "(-2,0,-1,0)", 1, 1)
    assert_distance("one", "(0,-2,0,-1)", 1, 1)

    assert_distance("one", "(-3,1,2,1,2,-2,-2,-2)", 1, 0.25)
    assert_distance("one", "(-3,2,2,2,2,-1,0,-1)", 1, 1)

    assert_distance("two", "(-1,1,1,1)", 0, 0.5)
    assert_distance("two", "(-2,-1,-1,1)", 1, 1)
    assert_distance("two", "(-1,0.25,1,0.25)", 0.25, 0.5)
  end

  def test_advanced
    feed_and_wait_for_docs("local", 4, :file => "#{selfdir}/advanced.xml");
    assert_hitcount("query=sddocname:local", 4);
    assert_hitcount("query=a", 1);
    assert_hitcount("query=b", 1);
    assert_hitcount("query=c", 1);
    assert_hitcount("query=d", 1);


    puts("                              \n" +
         " o--[ Y! MAPS ]--------------o\n" +
         " |                           |\n" +
         " |          (10,5)    (20,5) |\n" +
         " |             *---------*   |\n" +
         " |             |             |\n" +
         " |         B   |             |\n" +
         " |        A    |    C        |\n" +
         " |             |         D   |\n" +
         " |   *---------*    C        |\n" +
         " | (0,0)    (10,0)           |\n" +
         " |                           |\n" +
         " o---------------------------o\n")

    distance_query(1, { "A" => 0, "B" => 0, "C" => 0, "D" => 0 })
    distance_query(2, { "A" => 0, "B" => 0, "C" => 0, "D" => 0 })
    distance_query(3, { "A" => 1, "B" => 0, "C" => 0, "D" => 0 })
    distance_query(4, { "A" => 2, "B" => 1, "C" => 1, "D" => 0 })
    distance_query(5, { "A" => 3, "B" => 2, "C" => 2, "D" => 1 })

    traveled_query(0.00, { "A" => 6.4, "B" => 5.32, "C" => 1.4, "D" => 0 })
    traveled_query(0.25, { "A" => 7.6, "B" => 6.93, "C" => 3.15, "D" => 1.5 })
    traveled_query(0.50, { "A" => 5.6, "B" => 5.18, "C" => 4.9, "D" => 3 })
    traveled_query(0.75, { "A" => 3.6, "B" => 3.43, "C" => 6.65, "D" => 4.5 })
    traveled_query(1.00, { "A" => 1.6, "B" => 1.68, "C" => 5.6, "D" => 6 })

    puts("Perform advanced query with query(distance) = 4 and query(traveled) = 0.4 (point 2):");
    advanced_query(4, 0.4, "traveled", { "A" => 1.6, "B" => 0.84, "C" => 0.6, "D" => 0 })
  end

  def distance_query(distance, expected)
    puts("Perform query with query(distance) = #{distance}:");
    advanced_query(distance, 0, "distance", expected);
  end

  def traveled_query(traveled, expected)
    puts("Perform query with target query(traveled) = #{traveled}:")
    advanced_query(10, traveled, "traveled", expected);
  end

  def nearlyEqual(a, b)
    ccc = b + 1.5e-6
    if (a > ccc)
      return false
    end
    ccc = b - 1.5e-6
    if (a < ccc)
      return false
    end
    return true
  end

  def advanced_query(distance, traveled, ranking, expected)
    results = search("query=sddocname:local&rankproperty.distanceToPath(gps).path=(0,0,10,0,10,5,20,5)&" +
                     "rankproperty.distance=#{distance}&rankproperty.traveled=#{traveled}&ranking=#{ranking}")
    results.hit.each do |document|
      features = document.field['summaryfeatures']
      puts("- Relevancy " + document.field["relevancy"].to_s + ": " +
           "Document '" + document.field["title"] + "' with distance " +
           features.fetch("distanceToPath(gps).distance").to_s + " after " +
           features.fetch("distanceToPath(gps).traveled").to_s + " traveled.")

      rel = document.field["relevancy"].to_f
      exp = expected[document.field["title"]]
      assert(nearlyEqual(rel, exp), "relevance #{rel} !~ expected #{exp}")
    end
    puts("")
  end

  def assert_distance(title, path, distance, traveled)
    query = "query=#{title}&rankproperty.distanceToPath(gps).path=#{path}"
    assert_hitcount(query, 1)
    assert_features({ "distanceToPath(gps).distance" => distance,
                      "distanceToPath(gps).traveled" => traveled },
                    search(query).hit[0].field['summaryfeatures'])
  end

  def teardown
    stop
  end

end
