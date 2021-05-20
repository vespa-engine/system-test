# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'indexed_search_test'

class FriendFilter < SearchTest

  def timeout_seconds
    return 1200
  end

  def setup
    set_owner("arnej")
    set_description("Demonstrate friend filter use case for weighted set term search")
  end

  def test_weighted_set_item_casing
    add_bundle(selfdir + "FriendFilterSearcher.java")
    deploy_app(SearchApp.new.
               config(
                     ConfigOverride.new("search.querytransform.lowercasing").
                     add("transform_weighted_sets", "false")).
               sd(selfdir+"friendslist.sd").
               sd(selfdir+"blogpost.sd").
               threads_per_search(1).
               search_chain(SearchChain.new.add(Searcher.new("com.yahoo.test.FriendFilterSearcher"))))

    start
    feed(:file => selfdir+"casings.xml")
    wait_for_hitcount("sddocname:friendslist", 3)
    wait_for_hitcount("sddocname:blogpost", 12)

    assert_hitcount("query=title:foo", 6)
    assert_hitcount("query=title:bar", 6)

    assert_hitcount("query=author:null", 5)
    assert_hitcount("query=author:0", 7)

    assert_hitcount("query=title:foo+author:null", 2)
    assert_hitcount("query=title:bar+author:null", 3)

    assert_hitcount("query=title:foo&username=a1", 2)
    assert_hitcount("query=title:foo&username=b2", 2)
    assert_hitcount("query=title:foo&username=c3", 2)

    assert_hitcount("query=title:bar&username=a1", 3)
    assert_hitcount("query=title:bar&username=b2", 3)
    assert_hitcount("query=title:bar&username=c3", 3)

    assert_hitcount("query=sddocname:blogpost&username=a1", 5)
    assert_hitcount("query=sddocname:blogpost&username=b2", 0)
    assert_hitcount("query=sddocname:blogpost&username=c3", 0)
  end

  def test_friends_filter_plugin
    add_bundle(selfdir + "FriendFilterSearcher.java")
    deploy_app(SearchApp.new.
               sd(selfdir+"friendslist.sd").
               sd(selfdir+"blogpost.sd").
               search_chain(SearchChain.new.add(Searcher.new("com.yahoo.test.FriendFilterSearcher"))))

    start
    feed(:file => selfdir+"docs.xml")
    wait_for_hitcount("sddocname:friendslist", 2)
    wait_for_hitcount("sddocname:blogpost", 12)

  # save_result("tracelevel=1&query=title:foo",                         selfdir+"result.foo1.xml")
  # save_result("tracelevel=1&query=title:foo&username=default",        selfdir+"result.foo2.xml")
  # save_result("tracelevel=1&query=title:foo&username=arnej",          selfdir+"result.foo3.xml")
  # save_result("tracelevel=1&query=title:foo&username=paris+hilton",   selfdir+"result.foo4.xml")

    assert_result("query=title:foo",                         selfdir+"result.foo1.xml")
    assert_result("query=title:foo&username=default",        selfdir+"result.foo2.xml")
    assert_result("query=title:foo&username=arnej",          selfdir+"result.foo3.xml")
    assert_result("query=title:foo&username=paris+hilton",   selfdir+"result.foo4.xml")
  end

  def prime_sieve_upto(n)
    all_nums = (0..n).to_a
    all_nums[0] = all_nums[1] = nil
    all_nums.each do |p|
      #jump over nils
      next unless p
      #stop if we're too high already
      break if p * p > n
      #kill all multiples of this number
      (p*p).step(n, p){ |m| all_nums[m] = nil }
    end
    #remove unwanted nils
    all_nums.compact
  end

  def gen_friends(tfn)
    puts "generating friends lists in #{tfn}"
    primes = prime_sieve_upto(1000)
    File.open(tfn, "w") do |file|
      (1..666).each do |num|
        file.write("me: #{num} friends:")
        primes.each do |prime|
          friend = (num * 2.718281828 + prime * 3.1415926536).to_i % 1337 + 999
          file.write(" 14yrs4ever#{friend.to_i}")
        end
        file.write("\n")
      end
    end
  end

  def gen_docs(tfn)
    puts "generating feed in #{tfn}"
    File.open(tfn, "w") do |file|
      (1111..2222).each do |num|
        doc = Document.new("blogpost", "id:blogpost:blogpost::chat." + num.to_s).
          add_field("title",
            "omg! foo bar is teh awsum!!! lolz! DONT THEY WIZPUR SOFLY IN UR EARZ????!!!!111!!!!!1111").
          add_field("author", "14yrs4ever" + num.to_s).
          add_field("timestamp",  num)
        file.write(doc.to_xml)
        file.write("\n")
      end
    end
  end

  def test_friends_bm_plugin
    gen_friends(dirs.tmpdir + "more-friends-lists.txt")
    gen_docs(dirs.tmpdir + "more-feed-docs.xml")
    system("mkdir -p #{dirs.tmpdir}components")
    flf = dirs.tmpdir + "components/friendslists.txt"
    gen_friends(flf)

    add_bundle_dir(File.expand_path(selfdir + "bms"), "com.yahoo.test.FriendFilterBenchmark")
    deploy_app(SearchApp.new.
                      sd(selfdir+"friendslist.sd").
                      sd(selfdir+"blogpost.sd").
                      qrservers_jvmargs(
                        "-Xmx3333m -Xms3333m -XX:MaxDirectMemorySize=115m").
                      components_dir(dirs.tmpdir + "components").
                      search_chain(SearchChain.new.add(
                          Searcher.new("com.yahoo.test.FriendFilterBenchmark").
                          config(ConfigOverride.new("com.yahoo.vespatest.friendsfile").
                            add("friendslists", "components/friendslists.txt")
                          ))))

    start
    feed(:file => selfdir+"docs.xml")
    wait_for_hitcount("sddocname:friendslist", 2)
    wait_for_hitcount("sddocname:blogpost", 12)

    assert_result("query=title:foo", selfdir+"result.foo1.xml")

    tfn = dirs.tmpdir + "morefeed.xml"
    gen_docs(tfn)
    feed(:file => tfn)

  # save_result("sddocname:blogpost&nocache&hits=1&tracelevel=3", selfdir+"result.last-blogpost.xml")
    assert_result("sddocname:blogpost&nocache&hits=1", selfdir+"result.last-blogpost.xml")

    # before = Time.now().to_i
    # num = 0
    # while (Time.now().to_i < before + 300)
    #   num = 1 + num
    #   puts "Running queries, iteration #{num} ..."

    #   save_result("tracelevel=3&query=title:foo&friendfilter=next&nocache", dirs.tmpdir + "result.ff1.xml")
    #   save_result("tracelevel=3&query=title:foo&friendfilter=next&nocache", dirs.tmpdir + "result.ff2.xml")
    #   save_result("tracelevel=3&query=title:foo&friendfilter=next&nocache", dirs.tmpdir + "result.ff3.xml")
    #   save_result("tracelevel=3&query=title:foo&friendfilter=next&nocache", dirs.tmpdir + "result.ff4.xml")
    #   save_result("tracelevel=3&query=title:foo&friendfilter=next&nocache", dirs.tmpdir + "result.ff5.xml")
    #   save_result("tracelevel=3&query=title:foo&friendfilter=next&nocache", dirs.tmpdir + "result.ff6.xml")
    #   save_result("tracelevel=3&query=title:foo&friendfilter=next&nocache", dirs.tmpdir + "result.ff7.xml")
    #   save_result("tracelevel=3&query=title:foo&friendfilter=next&nocache", dirs.tmpdir + "result.ff8.xml")
    #   save_result("tracelevel=3&query=title:foo&friendfilter=next&nocache", dirs.tmpdir + "result.ff9.xml")
    # end

    # vespa.adminserver.execute("vespa-logfmt -S searchnode -l event -s fmttime,message")
  end

  def teardown
    stop
  end

end
