# Copyright Vespa.ai. All rights reserved.

require 'document_set'
require 'indexed_streaming_search_test'
require 'json'
require 'rubygems'

class FeatureNameQuoting < IndexedStreamingSearchTest

  def setup
    set_owner("yngve")
    deploy_app(SearchApp.new.sd("#{selfdir}/featurenamequoting.sd"))
    start
  end

  def test_featureNameQuoting
    # Create and feed some synthetic data.
    docs = DocumentSet.new
    0.upto(9) do |i|
      doc = Document.new("featurenamequoting", "id:scheme:featurenamequoting::#{i}")
      doc.add_field("foo", i)
      docs.add(doc)
    end

    feed_file = "#{dirs.tmpdir}/feed.json"
    docs.write_json(feed_file)
    feed_and_wait_for_docs("featurenamequoting", 10, :file => feed_file);

    # Assert the ranking expression of profile 1.
    puts("Asserting profile 1..");
    result = search("query=sddocname:featurenamequoting&parallel&skipnormalizing&ranking=profile1");
    result.hit.each_index do |i|
      score = result.hit[i].field["relevancy"].to_i;
      exp = 2 * ( (9 - i) + 1 + 2 + 3 )
      assert(score == exp, "Expected relevancy #{exp} for document #{i}, got #{score}.");
    end

    # Assert the ranking expression and features of profile 2.
    puts("Asserting profile 2..");
    result = search("query=sddocname:featurenamequoting&parallel&skipnormalizing&rankfeatures&ranking=profile2");
    result.hit.each_index do |i|
      score = result.hit[i].field["relevancy"].to_i;
      exp = 1 + 2 * (3 + (9 - i) + (1 + 2 + 3));
      assert(score == exp, "Expected relevancy #{exp} for document #{i}, got #{score}.");

      assertFeatures(9 - i, result.hit[i].field["summaryfeatures"]);
      assertFeatures(9 - i, result.hit[i].field["rankfeatures"]);
    end
  end

  def assertFeatures(foo, field)

    # If you are checking the content of this method because this test broke with a JSON parse exception, it is highly
    # likely that there is a feature that was broken within searchlib. If JSON encounters a "nan" string as an object
    # value it will break. Look through the systemtest output and see if you find a "<feature>:nan" string in there. If
    # you do, then that feature is broken.

    puts("Asserting features '#{field}'..");
    features = field;

    assert(features.fetch("value(3)").to_i == 3);
    assert(features.fetch("double(\" attribute( \\\"foo\\\"  )\")").to_i == 2 * foo);
  end

  def teardown
    stop
  end

end
