# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_only_search_test'

class MultiplePositions < IndexedOnlySearchTest

  def initialize(*args)
    super(*args)
  end

  def setup
    set_owner('arnej')
    set_description('Test single and multivalued input to positions with various legacy formats')
    @rfn = 1
  end

  def fixhit(h)
    h.field.delete('source')
    sf = h.field['summaryfeatures']
    return unless sf
    if sf.instance_of?(String)
      sf = JSON.parse(sf)
    end
    if sf.instance_of?(Hash)
      sf.delete('vespa.summaryFeatures.cached')
    end
    h.field['summaryfeatures'] = sf
  end

  def my_cmp(q, fn)
    # NOTE: result from search(q) is a remote object, trying to modify
    # hits inside there just won't work
    act = Resultset.new(search(q).xmldata, q)
    exp = create_resultset(fn)
    act.hit.each { |h| fixhit(h) }
    exp.hit.each { |h| fixhit(h) }
    details = "for query #{q} (answer file: #{fn})"
    assert_equal(exp.hitcount, act.hitcount, "Expected #{exp.hitcount} hits but got #{act.hitcount} #{details}")
    exp.hit.each_index do |i|
      assert_equal(exp.hit[i], act.hit[i], "Mismatch in hit #{i} #{details}")
    end
  end

  def check_q(query, hc, fn = nil)
    xq = query + '&format=xml'
    jq = query + '&format=json'
    rf = "result-#{@rfn}"
    @rfn = @rfn + 1
    # save_result(xq, selfdir + rf + '.xml')
    # save_result(jq, selfdir + rf + '.json')
    assert_hitcount(xq, hc)
    assert_hitcount(jq, hc)
    if fn
      my_cmp(xq, selfdir + fn + '.xml')
      my_cmp(jq, selfdir + fn + '.json')
    end
  end

  def check_sq(q, hc, fn = nil)
    query = q + '&restrict=singlepos2d'
    check_q(query, hc, fn)
  end

  def check_mq(q, hc, fn = nil)
    query = q + '&restrict=multiplepos2d' + '&pos.attribute=ll'
    check_q(query, hc, fn)
  end

  def check_spos(pos, hc, fn = nil)
    query = 'query=sddocname:singlepos2d&' + pos + '&restrict=singlepos2d'
    check_q(query, hc, fn)
  end

  def check_mpos(pos, hc, fn = nil)
    query = 'query=sddocname:multiplepos2d&' + pos + '&pos.attribute=ll'
    check_q(query, hc, fn)
  end

  def test_multiplepos_2d
    deploy_app(SearchApp.new.
               legacy_override('v7-geo-positions', 'true').
               sd(selfdir+'singlepos2d.sd').
               sd(selfdir+'multiplepos2d.sd'))
    start
    feed_and_wait_for_docs('singlepos2d', 12, :file => selfdir+'docs-sp.xml')
    puts 'Query: Search with single position'

    check_spos('pos.ll=63.4225N+10.3637E', 10, 'res-sp1')
    check_spos('pos.ll=63.4225N+10.3637E&pos.radius=5km', 6)
    check_spos('pos.ll=63.4225N+10.3637E&pos.radius=100m', 1)

    check_sq('query=Steinberget', 1, 'res-sp-nopos')
    check_sq('query=Steinberget&pos.ll=0N+0E', 0)
    check_sq('query=Steinberget&pos.ll=63N25+10E25', 1, 'res-sp2')

    feed_and_wait_for_docs('multiplepos2d', 4, :file => selfdir+'docs-mp.json')
    puts 'Query: Search with multiple positions'

    check_mpos('pos.ll=63.4225N+10.3637E', 2)
    check_mpos('pos.ll=63.4225N+10.3637E&pos.radius=5km', 2, 'res-mp1')
    check_mpos('pos.ll=63.4225N+10.3637E&pos.radius=100m', 1)

    check_mpos('pos.ll=63N25+10E25', 2)
    check_mpos('pos.ll=N0+E0', 1)
    check_mpos('pos.ll=N0+E180', 1)

    check_mq('query=Trondheim1', 1, 'res-mp-nopos')
    check_mq('query=Trondheim1&pos.ll=0N%3B0E', 0)
    check_mq('query=Trondheim1&pos.ll=63N25%3B10E25&pos.radius=100km', 1)
    check_mq('query=Trondheim1&pos.ll=0N+0E', 0)
    check_mq('query=Trondheim1&pos.ll=63N25+10E25&pos.radius=100km', 1)
  end

  def test_v7_positions_summary_rendering
    deploy_app(SearchApp.new.
               legacy_override('v7-geo-positions', 'true').
               sd(selfdir+'renderpos.sd'))
    start
    feed_and_wait_for_docs('renderpos', 4, :file => selfdir+'docs-render.json')
    check_q('/search/?yql=select+*+from+sources+*+where+true%3B', 4, 'v7-render')
  end


  def teardown
    stop
  end

end
