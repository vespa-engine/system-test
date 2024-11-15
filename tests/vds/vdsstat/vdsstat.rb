# Copyright Vespa.ai. All rights reserved.
require 'vds_test'

class VdsStat < VdsTest

  def setup
    set_owner("vekterli")
    deploy_app(default_app.
               bucket_split_count(2).
               num_nodes(3).
               redundancy(2))
    start
  end

  def cleanstring(str)
    return str.gsub(/crc=0x[0-9a-f]+,/, "crc=,").
               gsub(/docs=([0-9]+)\/[0-9]+/, "docs=\\1/").
               gsub(/bytes=[0-9]+\/[0-9]+/, "bytes=").
               gsub(/idx=[0-9]+/, "idx=").
               gsub(/active=[a-z]+/, "active=").
               gsub(/distributor:[0-9]+/, "distributor:x").
               gsub(/node [0-9]+/,"").
               gsub(/checksum: [0-9a-f]+/, "").
               gsub(/Timestamp:[^,]*,/,"Timestamp:,").
               gsub(/Checksum 0x[0-9a-f]+,/, "").
               gsub(/ \(fd [0-9]+\)/, "").
               gsub(/^\s+/, "").
               gsub(/Header block: \([0-9]+b\)/, "Header block: (X b)").
	       gsub(/Header pos: ([^-]+)/, "Header pos: X -").
               gsub(/header block size: [0-9]+b/, "header block size: X b").
               gsub(/meta data list size: [0-9]+/, "meta data list size: X").
               gsub(/Content block: \([0-9]+b\)/, "Content block: (X b)").
	       gsub(/Filesize: ([0-9]+)/, "Filesize: X").
	       gsub(/storage\/[0-9]\/disks/, "storage/X/disks")
  end

  def test_stat
    doc = Document.new("music", "id:storage_test:music:n=1234:1")
    vespa.document_api_v1.put(doc)

    doc = Document.new("music", "id:storage_test:music:n=1234:2")
    vespa.document_api_v1.put(doc)

    doc = Document.new("music", "id:storage_test:music:n=1234:3")
    vespa.document_api_v1.put(doc)

    # 66770 is in same bucket as 1234
    doc = Document.new("music", "id:storage_test:music:n=66770:1")
    vespa.document_api_v1.put(doc)

    doc = Document.new("music", "id:storage_test:music:n=66770:2")
    vespa.document_api_v1.put(doc)

    doc = Document.new("music", "id:storage_test:music:n=66770:3")
    vespa.document_api_v1.put(doc)

    # Feed a group as well.
    doc = Document.new("music", "id:storage_test:music:g=mygroup:1")
    vespa.document_api_v1.put(doc)

    doc = Document.new("music", "id:storage_test:music:g=mygroup:2")
    vespa.document_api_v1.put(doc)

    doc = Document.new("music", "id:storage_test:music:g=mygroup:3")
    vespa.document_api_v1.put(doc)

    vespa.storage["storage"].wait_until_ready

    value = vespa.storage["storage"].storage["0"].execute("vespa-stat --user 1234")

    correct = "Generated 32-bit bucket id: BucketId(0x80000000000004d2)\n" +
              "Bucket maps to the following actual files:\n" +
              "\tBucketInfo(BucketId(0x84000000000004d2): [distributor:0] [node(idx=1,crc=0x2bfee69e,docs=1/1,bytes=82/82,trusted=true,active=false,ready=true), node(idx=2,crc=0x2bfee69e,docs=1/1,bytes=82/82,trusted=true,active=false,ready=true)])\n" +
              "\tBucketInfo(BucketId(0x84000001000004d2): [distributor:0] [node(idx=0,crc=0x62e9afd6,docs=2/2,bytes=164/164,trusted=true,active=false,ready=true), node(idx=1,crc=0x62e9afd6,docs=2/2,bytes=164/164,trusted=true,active=false,ready=true)])\n";

    assert_equal(cleanstring(correct), cleanstring(value))

    value = vespa.storage["storage"].storage["0"].execute("vespa-stat --bucket 0x40000000000004d2")

    correct = "Bucket maps to the following actual files:\n" +
        "\tBucketInfo(BucketId(0x84000000000004d2): [distributor:0] [node(idx=1,crc=0x2bfee69e,docs=1/1,bytes=82/82,trusted=true,active=false,ready=true), node(idx=2,crc=0x2bfee69e,docs=1/1,bytes=82/82,trusted=true,active=false,ready=true)])\n" +
        "\tBucketInfo(BucketId(0x84000001000004d2): [distributor:0] [node(idx=0,crc=0x62e9afd6,docs=2/2,bytes=164/164,trusted=true,active=false,ready=true), node(idx=1,crc=0x62e9afd6,docs=2/2,bytes=164/164,trusted=true,active=false,ready=true)])\n" +
        "\tBucketInfo(BucketId(0x84000000000104d2): [distributor:0] [node(idx=0,crc=0xa5fc1520,docs=1/1,bytes=84/84,trusted=true,active=false,ready=true), node(idx=1,crc=0xa5fc1520,docs=1/1,bytes=84/84,trusted=true,active=false,ready=true)])\n" +
        "\tBucketInfo(BucketId(0x84000001000104d2): [distributor:0] [node(idx=1,crc=0x3b66fcd2,docs=2/2,bytes=168/168,trusted=true,active=false,ready=true), node(idx=2,crc=0x3b66fcd2,docs=2/2,bytes=168/168,trusted=true,active=false,ready=true)])\n"

    assert_equal(cleanstring(correct), cleanstring(value))

    value = vespa.storage["storage"].storage["0"].execute("vespa-stat --group mygroup")

    correct = "Generated 32-bit bucket id: BucketId(0x800000003a7455d7)\n" +
              "Bucket maps to the following actual files:\n" +
              "\tBucketInfo(BucketId(0x840000003a7455d7): [distributor:0] [node(idx=0,crc=0x3c6277a7,docs=1/1,bytes=90/90,trusted=true,active=false,ready=true), node(idx=2,crc=0x3c6277a7,docs=1/1,bytes=90/90,trusted=true,active=false,ready=true)])\n" +
              "\tBucketInfo(BucketId(0x840000013a7455d7): [distributor:0] [node(idx=0,crc=0x643a2091,docs=2/2,bytes=180/180,trusted=true,active=false,ready=true), node(idx=1,crc=0x643a2091,docs=2/2,bytes=180/180,trusted=true,active=false,ready=true)])\n"

    assert_equal(cleanstring(correct), cleanstring(value))

    value = vespa.storage["storage"].storage["0"].execute("vespa-stat --user 1234 --dump")
    fname = selfdir + "/1234.dump"
    correct = File.open(fname) { |f| f.read }
    assert(value =~ /Doc/)

    value = vespa.storage["storage"].storage["0"].execute("vespa-stat --document id:storage_test:music:g=mygroup:2")
    fname = selfdir + "/doc.dump"
    correct = File.open(fname) { |f| f.read }
    assert(value =~ /Doc/)

    value = vespa.storage["storage"].storage["0"].execute("vespa-stat --gid 0xd755743a4624d818b89abe0f")
    fname = selfdir + "/gid.dump"
    correct = File.open(fname) { |f| f.read }
    assert(value =~ /Doc/)
  end

  def teardown
    stop
  end

end
