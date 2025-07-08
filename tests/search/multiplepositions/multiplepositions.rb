# Copyright Vespa.ai. All rights reserved.
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

  def teardown
    stop
  end

end
