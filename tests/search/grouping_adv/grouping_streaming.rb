# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'streaming_search_test'
require 'search/grouping_adv/grouping_base'

class GroupingStreaming < StreamingSearchTest

  include GroupingBase

  def test_advgrouping_struct_vds
    deploy_app(singlenode_streaming_2storage("#{selfdir}/structtest.sd"))
    start
    feed_and_wait_for_docs('structtest', 1, :file => "#{selfdir}/structdocs.xml")
    # Test struct
    check_wherequery("sddocname:structtest", "all%28group%28ssf1.s1%29 each%28output%28count%28%29%29%29%29", "#{selfdir}/ssf1.s1.xml")
    check_wherequery("sddocname:structtest", "all%28group%28ssf1.l1%29 each%28output%28count%28%29%29%29%29", "#{selfdir}/ssf1.l1.xml")
    check_wherequery("sddocname:structtest", "all%28group%28asf1.s1%29 each%28output%28count%28%29%29%29%29", "#{selfdir}/asf1.s1.xml")
    check_wherequery("sddocname:structtest", "all%28group%28asf1.l1%29 each%28output%28count%28%29%29%29%29", "#{selfdir}/asf1.l1.xml")

  end

  def test_advgrouping_vds
    deploy_app(singlenode_streaming_2storage("#{selfdir}/test.sd"))
    start
    feed_docs

    querytest_common

    # Test where
    check_query("all%28group%28a%29 each%28output%28count%28%29%29%29%29",
                "#{selfdir}/where-allhits.xml")
    check_wherequery("a:a1", "all%28group%28a%29 each%28output%28count%28%29%29%29%29",
                     "#{selfdir}/where-a1.xml")
    check_query("all%28where%28true%29 all%28group%28a%29 each%28output%28count%28%29%29%29%29%29",
                "#{selfdir}/where-all-28.xml")
    check_wherequery("a:a1","all%28where%28true%29 all%28group%28a%29 each%28output%28count%28%29%29%29%29%29",
                     "#{selfdir}/where-all-10.xml")

  end

  def test_hits_in_best_group
    set_owner("bjorncs")
    deploy_app(singlenode_streaming_2storage("#{selfdir}/test.sd"))
    start
    feed_docs
    check_query("all(group(a)max(1)each(each(output(summary()))))", "#{selfdir}/best-group1.xml")
  end

end
