# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'streaming_search_test'
require 'search/grouping_adv/grouping_base'

class GroupingStreaming < StreamingSearchTest

  include GroupingBase

  def test_advgrouping_struct_vds
    deploy_app(singlenode_streaming_2storage("#{selfdir}/structtest.sd").search_dir(selfdir + 'search'))
    start
    feed_and_wait_for_docs('structtest', 1, :file => "#{selfdir}/structdocs.xml")
    # Test struct
    check_wherequery('sddocname:structtest', 'all(group(ssf1.s1) each(output(count())))', 'ssf1.s1')
    check_wherequery('sddocname:structtest', 'all(group(ssf1.l1) each(output(count())))', 'ssf1.l1')
    check_wherequery('sddocname:structtest', 'all(group(asf1.s1) each(output(count())))', 'asf1.s1')
    check_wherequery('sddocname:structtest', 'all(group(asf1.l1) each(output(count())))', 'asf1.l1')

  end

  def test_advgrouping_vds
    deploy_app(singlenode_streaming_2storage(selfdir + 'test.sd').search_dir(selfdir + 'search'))
    start
    feed_docs

    querytest_common

    # Test where
    check_query('all(group(a) each(output(count())))', 'where-allhits')
    check_wherequery('a:a1', 'all(group(a) each(output(count())))', 'where-a1')
    check_query('all(where(true) all(group(a) each(output(count()))))', 'where-all-28')
    check_wherequery('a:a1','all(where(true) all(group(a) each(output(count()))))', 'where-all-10')

  end

  def test_global_max
    set_owner('bjorncs')
    deploy_app(singlenode_streaming_2storage("#{selfdir}/test.sd").search_dir("#{selfdir}/global-max"))
    start
    feed_docs
    querytest_global_max
  end

  def test_groups_for_default_value
    set_owner("bjorncs")
    deploy_app(singlenode_streaming_2storage(selfdir+"test.sd"))
    start
    feed_and_wait_for_docs('test', 7, :file => "#{selfdir}/default-values-docs.json")
    querytest_groups_for_default_value(true)
  end

end
