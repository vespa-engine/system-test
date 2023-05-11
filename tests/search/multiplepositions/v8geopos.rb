# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'indexed_streaming_search_test'

class Vespa8GeoPositions < IndexedStreamingSearchTest

  def initialize(*args)
    super(*args)
  end

  def setup
    set_owner('arnej')
    set_description('Test single and multivalued positions with Vespa 8 output')
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

  def check_spos(pos, hc, fn = nil)
    query = 'query=sddocname:singlepos2d&' + pos
    check_q(query, hc, fn)
  end

  def check_mpos(pos, hc, fn = nil)
    query = 'query=sddocname:multiplepos2d&' + pos + '&pos.attribute=ll'
    check_q(query, hc, fn)
  end

  def test_v8_single_position
    deploy_app(SearchApp.new.
               legacy_override('v7-geo-positions', 'false').
               sd(selfdir+'singlepos2d.sd'))
    start
    feed_and_wait_for_docs('singlepos2d', 12, :file => selfdir+'docs-sp.xml')
    #vespa.adminserver.execute('vespa-logctl searchnode:vsm debug=on')
    #vespa.adminserver.execute('vespa-logctl searchnode:searchvisitor debug=on')
    #vespa.adminserver.execute('vespa-logctl searchnode:visitor.instance.searchvisitor debug=on')
    #vespa.adminserver.execute('vespa-logctl searchnode:searchlib.docsummary debug=on')
    #vespa.adminserver.execute('vespa-logctl searchnode:features.distancefeature debug=on')
    #vespa.adminserver.execute('vespa-logctl searchnode:features.great_circle_distance_feature debug=on')
    check_spos('pos.ll=63.4225N+10.3637E', 10, 'v8-sp3')
  end

  def test_v8_multi_positions
    deploy_app(SearchApp.new.
               legacy_override('v7-geo-positions', 'false').
               sd(selfdir+'multiplepos2d.sd'))
    start
    #vespa.adminserver.execute('vespa-logctl searchnode:vsm debug=on')
    #vespa.adminserver.execute('vespa-logctl searchnode:searchvisitor debug=on')
    #vespa.adminserver.execute('vespa-logctl searchnode:visitor.instance.searchvisitor debug=on')
    #vespa.adminserver.execute('vespa-logctl searchnode:searchlib.docsummary debug=on')
    #vespa.adminserver.execute('vespa-logctl searchnode:features.distancefeature debug=on')
    #vespa.adminserver.execute('vespa-logctl searchnode:features.great_circle_distance_feature debug=on')
    feed_and_wait_for_docs('multiplepos2d', 4, :file => selfdir+'docs-mp.json')
    preq = '/search/?yql=select+*+from+sources+*+where+'
    check_q(preq + 'true%3B', 4, 'v8-nopos')
    check_mpos('pos.ll=63.4225N+10.3637E&pos.radius=15km', 2, 'v8-mp3')
    check_q(preq + 'geoLocation(ll,63.4,10.4,%22500+km%22)%3B', 2, 'v8-mp4')
    check_q(preq + 'geoLocation(ll,60.0,10.0,%22999+km%22)+AND+' +
                   'geoLocation(workplaces,64.0,10.0,%22999+km%22)%3B', 2, 'v8-mp5')
  end

  def test_v8_positions_summary_rendering
    deploy_app(SearchApp.new.
               legacy_override('v7-geo-positions', 'false').
               sd(selfdir+'renderpos.sd'))
    start
    feed_and_wait_for_docs('renderpos', 4, :file => selfdir+'docs-render.json')
    check_q('/search/?yql=select+*+from+sources+*+where+true%3B', 4, 'v8-render')
  end

  def teardown
    stop
  end

end
