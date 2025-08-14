# Copyright Vespa.ai. All rights reserved.
require 'streaming_search_test'
require 'search/grouping_adv/grouping_base'

class GroupingStreaming < StreamingSearchTest

  include GroupingBase

  def test_advgrouping_struct_vds
    deploy_app(singlenode_streaming_2storage("#{selfdir}/structtest.sd").search_dir(selfdir + 'search'))
    start
    feed_and_wait_for_docs('structtest', 1, :file => "#{selfdir}/structdocs.json")
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

    # Test buckets with map value
    check_query('all(group(predefined(msd{k1},bucket(1,3),bucket(6,9))) each(output(count())))', 'streaming-predef5')
    check_query('all(group(predefined(msd{k2},bucket(1,3),bucket(6,inf))) each(output(count())))', 'streaming-predef6')
    check_query('all(group(fixedwidth(msd{k1},3)) each(output(count())))',
                'streaming-fixedwidth-mk1-3')
    check_query('all(group(fixedwidth(msd{k2},3)) each(output(count())))',
                'streaming-fixedwidth-mk2-3')

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
