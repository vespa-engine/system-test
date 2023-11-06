# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'vds_test'

class SplitWithCollisions < VdsTest

  def setup
    set_owner("vekterli")
    set_description("Test that a bucket containing separate document IDs " +
                    "whose 58-bit bucket IDs are identical when trying to " +
                    "compute a differing bucket bit between the two will be " +
                    "split to 58 bits and not joined back.")
    set_expected_logged(/Forcing resulting bucket to be 58 bits/)

    # Use config override to force 1 doc per bucket, as config model may reject
    # this if specified in the actual services.xml file. Disable join or
    # distributors will reject config.
    deploy_app(default_app.
               config(ConfigOverride.new('vespa.config.content.core.stor-distributormanager').
                      add('splitcount', 1).
                      add('joincount', 0)))
    start
  end

  def bucket_containing_id(id)
    output = vespa.adminserver.execute("vespa-stat --document #{id} --route storage")
    output.each_line do |line|
      if line =~ /BucketInfo\(BucketId\((0x[0-9a-f]+)\)/
        return $~[1]
      end
    end
    raise "Could not find a bucket ID in vespa-stat output"
  end

  def bucket_used_bits(bucket_id)
    bucket_id >> 58
  end

  def test_buckets_containing_only_colliding_documents_are_split_to_58_bits
    # The following differing document IDs both compute an identical
    # bucket ID (0xea9124d40001e240), causing any split to fail unless
    # "unsplittable" buckets are handled by forcing these to 58 bits.
    # The colliding ID was found by running brute force permutations of
    # the user-specific part of doc1's document ID and a collision was
    # found after ~22 million iterations.
    doc1 = Document.new("music", "id:foo:music:n=123456:ABCDEFGHIJKLMN").
        add_field("title", "foo")
    vespa.document_api_v1.put(doc1)

    doc2 = Document.new("music", "id:foo:music:n=123456:ABCJGFMKIDNLEH").
        add_field("title", "bar")
    vespa.document_api_v1.put(doc2)

    vespa.storage["storage"].wait_until_ready

    doc1_bucket = bucket_containing_id(doc1.documentid)
    doc2_bucket = bucket_containing_id(doc2.documentid)

    assert_equal(doc1_bucket, doc2_bucket)
    puts "Both documents contained in #{doc1_bucket}"
    assert_equal(58, bucket_used_bits(doc1_bucket.to_i(16)))
  end

  def teardown
    stop
  end

end

