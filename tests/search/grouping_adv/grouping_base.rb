# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
module GroupingBase

  SAVE_RESULT = false

  DEFAULT_TIMEOUT = 10

  def setup
    set_owner("bjorncs")
  end

  def can_share_configservers?(method_name=nil)
    true
  end

  def feed_docs
    feed_and_wait_for_docs('test', 28, :file => "#{selfdir}/docs.json")
  end

  def querytest_common
    wait_for_hitcount("query=test&streaming.selection=true", 28, 10)

    # Test subgrouping.
    check_query("all(group(a) max(5) each(output(count()) each(output(summary(normal)))))",
                "#{selfdir}/subgroup1.json")
    check_query("all(group(a) max(5) each(max(69) output(count()) each(output(summary(normal)))))",
                "#{selfdir}/subgroup1.json")
    check_query("all(group(a) max(5) each(output(count()) all(group(b) max(5) each(max(69) output(count()) each(output(summary(normal)))))))",
                "#{selfdir}/subgroup2.json")
    check_query("all(group(a) max(5) each(output(count()) all(group(b) max(5) each(output(count()) all(group(c) max(5) each(max(69) output(count()) each(output(summary(normal)))))))))",
                "#{selfdir}/subgroup3.json")
    check_query("all(group(fixedwidth(n,3)) max(5) each(output(count()) all(group(a) max(2) each(output(count())))))",
                "#{selfdir}/subgroup4.json")
    check_query("all(group(fixedwidth(n,3)) max(5) each(output(count()) all(group(a) max(2) each(output(count())))))",
                "#{selfdir}/subgroup5.json")
    check_query("all(group(fixedwidth(n,3)) max(5) each(output(count()) all(group(a) max(2) each(max(1) output(count()) each(output(summary(normal)))))))",
                "#{selfdir}/subgroup6.json")

    # Test orderby
    check_query("all(group(a) order(-sum(from)) each(output(count())))",
                "#{selfdir}/orderby1.json")
    check_query("all(group(a) order(sum(from)) each(output(count())))",
                "#{selfdir}/orderby-1.json")

    check_query("all(group(a) max(2) order(-sum(from)) precision(3) each(output(count())))",
                "#{selfdir}/orderby1-m1.json")
    check_query("all(group(a) max(2) order(sum(from)) precision(3) each(output(count())))",
                "#{selfdir}/orderby-1-m1.json")
    check_query("all(group(a) max(2) order(-count()) each(output(count())))",
                "#{selfdir}/orderby2.json")

    # Test combination
    check_query("all(group(a) max(2) order(-count()) each(output(count())) as(foo) each(output(max(b))) as(bar))",
                "#{selfdir}/combination-1.json")

    # Test limit and precision
    topn_xml = run_xml_query("all(all(group(a) each(output(count()))))")
    sum=0
    topn_xml.elements.each("group/grouplist/group/output") { |element| sum = sum + element.text.to_i }
    assert(sum == 28)
    topn_xml = run_xml_query("all(max(2) all(group(a) each(output(count()))))")
    sum=0
    topn_xml.elements.each("group/grouplist/group/output") { |element| sum = sum + element.text.to_i }
    puts "sum = " + sum.to_s
    assert(sum <= 2*8)

    check_query("all(group(a) max(2) each(output(count())))", "#{selfdir}/constraint2.json")
    check_query("all(group(a) max(2) precision(10) each(output(count())))", "#{selfdir}/constraint3.json")

    # Test time.(year,day,month,yday,wday,hour,min,sec)
    check_query("all(group(time.year(from)) each(output(count()) ))", "#{selfdir}/time.year.json")
    check_query("all(group(time.monthofyear(from)) each(output(count()) ))", "#{selfdir}/time.month.json")
    check_query("all(group(time.hourofday(from)) each(output(count()) ))", "#{selfdir}/time.hour.json")
    check_query("all(group(time.secondofminute(from)) each(output(count()) ))", "#{selfdir}/time.second.json")
    check_query("all(group(time.minuteofhour(from)) each(output(count()) ))", "#{selfdir}/time.minute.json")
    check_query("all(group(time.dayofmonth(from)) each(output(count()) ))", "#{selfdir}/time.mday.json")
    check_query("all(group(time.dayofyear(from)) each(output(count()) ))", "#{selfdir}/time.yday.json")
    check_query("all(group(time.dayofweek(from)) each(output(count()) ))", "#{selfdir}/time.wday.json")

    # Test relevance
    check_query("all(group(a) each(output(count(),sum(mod(relevance(),100000))) ))", "#{selfdir}/relevance.json")

    # Test cat
    check_query("all(group(cat(a,b,c)) each(output(count())))", "#{selfdir}/cat.json")

    # Test zcurve
    check_query("all(group(zcurve.x(to)) each(output(count())))", "#{selfdir}/zcurve.x.json")
    check_query("all(group(zcurve.y(to)) each(output(count())))", "#{selfdir}/zcurve.y.json")

    # Test aritmetic expressions (add, sub, mul, div, mod)
    check_query("all(group(add(f,f)) each(output(count())))", "#{selfdir}/add-ff.json")
    check_query("all(group(add(n,f)) each(output(count())))", "#{selfdir}/add-nf.json")
    check_query("all(group(mul(2,f)) each(output(count())))", "#{selfdir}/mul-2f.json")
    check_query("all(group(mul(n,f)) each(output(count())))", "#{selfdir}/mul-nf.json")
    check_query("all(group(sub(f,f)) each(output(count())))", "#{selfdir}/sub-ff.json")
    check_query("all(group(sub(f,n)) each(output(count())))", "#{selfdir}/sub-fn.json")
    check_query("all(group(div(f,n)) each(output(count())))", "#{selfdir}/div-fn.json")
    check_query("all(group(div(f,f)) each(output(count())))", "#{selfdir}/div-ff.json")
    check_query("all(group(mod(f,n)) each(output(count())))", "#{selfdir}/mod-fn.json")
    check_query("all(group(mod(n,f)) each(output(count())))", "#{selfdir}/mod-nf.json")
    check_query("all(group(mod(f,f)) each(output(count())))", "#{selfdir}/mod-2f.json")

    # Test alternative ranking.
    check_query("all(group(a) order(sum(relevance()),-count()) each(output(count(),sum(mod(relevance(),100000))) ))", "#{selfdir}/rank-relevance-count.json")

    # Test strcat
    check_query("all(group(strcat(a,b,c)) each(output(count())))", "#{selfdir}/strcat.json")
    check_query("all(group(strcat(a,n,d)) each(output(count())))", "#{selfdir}/strcat-int-double.json")
    check_query("all(group(strcat(a,n,na)) each(output(count())))", "#{selfdir}/strcat-array.json")
    check_query("all(group(strcat(a,n,nw)) each(output(count())))", "#{selfdir}/strcat-ws.json")
    # Test strlen
    check_query("all(group(strlen(strcat(a,b,c))) each(output(count())))", "#{selfdir}/strlen.json")

    check_query("all(group(tostring(f)) each(output(count())))", "#{selfdir}/tostring-f.json")
    check_query("all(group(tostring(n)) each(output(count())))", "#{selfdir}/tostring-n.json")
    check_query("all(group(tostring(sf)) each(output(count())))", "#{selfdir}/tostring-sf.json")
    check_query("all(group(tolong(f)) each(output(count())))", "#{selfdir}/tolong-f.json")
    check_query("all(group(tolong(n)) each(output(count())))", "#{selfdir}/tolong-n.json")
    check_query("all(group(tolong(sf)) each(output(count())))", "#{selfdir}/tolong-sf.json")
    check_query("all(group(todouble(d)) each(output(count())))", "#{selfdir}/todouble-d.json")
    check_query("all(group(todouble(f)) each(output(count())))", "#{selfdir}/todouble-f.json")
    check_query("all(group(todouble(n)) each(output(count())))", "#{selfdir}/todouble-n.json")
    check_query("all(group(todouble(sf)) each(output(count())))", "#{selfdir}/todouble-sf.json")

    # Test math operations
    check_query("all(group(math.exp(d)) each(output(count())))", "#{selfdir}/math.exp.json")
    check_query("all(group(math.log(d)) each(output(count())))", "#{selfdir}/math.log.json")
    check_query("all(group(math.log1p(d)) each(output(count())))", "#{selfdir}/math.log1p.json")
    check_query("all(group(math.log10(d)) each(output(count())))", "#{selfdir}/math.log10.json")
    check_query("all(group(math.sin(d)) each(output(count())))", "#{selfdir}/math.sin.json")
    check_query("all(group(math.asin(d)) each(output(count())))", "#{selfdir}/math.asin.json")
    check_query("all(group(math.cos(d)) each(output(count())))", "#{selfdir}/math.cos.json")
    check_query("all(group(math.acos(d)) each(output(count())))", "#{selfdir}/math.acos.json")
    check_query("all(group(math.tan(d)) each(output(count())))", "#{selfdir}/math.tan.json")
    check_query("all(group(math.atan(d)) each(output(count())))", "#{selfdir}/math.atan.json")
    check_query("all(group(math.sqrt(d)) each(output(count())))", "#{selfdir}/math.sqrt.json")
    check_query("all(group(math.sinh(d)) each(output(count())))", "#{selfdir}/math.sinh.json")
    check_query("all(group(math.asinh(d)) each(output(count())))", "#{selfdir}/math.asinh.json")
    check_query("all(group(math.cosh(d)) each(output(count())))", "#{selfdir}/math.cosh.json")
    check_query("all(group(math.acosh(d)) each(output(count())))", "#{selfdir}/math.acosh.json")
    check_query("all(group(math.tanh(d)) each(output(count())))", "#{selfdir}/math.tanh.json")
    check_query("all(group(math.atanh(d/10)) each(output(count())))", "#{selfdir}/math.atanh.json")
    check_query("all(group(math.cbrt(d)) each(output(count())))", "#{selfdir}/math.cbrt.json")
    check_query("all(group(math.pow(d,d)) each(output(count())))", "#{selfdir}/math.pow.json")
    check_query("all(group(math.hypot(d,d)) each(output(count())))", "#{selfdir}/math.hypot.json")

    # Test length(NumElemFunctionNode
    check_query("all(group(size(na)) each(output(count())))", "#{selfdir}/length-a.json")
    check_query("all(group(size(nw)) each(output(count())))", "#{selfdir}/length-w.json")

    # Test predefined buckets
    check_query("all(group(predefined(n,bucket(1,3),bucket(6,9))) each(output(count())))", "#{selfdir}/predef1.json")
    check_query("all(group(predefined(f,bucket(-inf,3),bucket(6,9))) each(output(count())))", "#{selfdir}/predef1.2.json")
    check_query("all(group(predefined(f,bucket(1.0,3.0),bucket(6.0,9.0))) each(output(count())))",
                "#{selfdir}/predef2.json")
    check_query("all(group(predefined(s,bucket(\"ab\",\"abc\"),bucket(\"abc\",\"bc\"))) each(output(count())))",
                "#{selfdir}/predef3.json")
    check_query("all(group(predefined(d, bucket(-inf, 0.0), bucket(0.0, inf))) each(output(count())))",
                "#{selfdir}/predef4.json")

    # Test fixedwidth buckets
    check_query("all(group(fixedwidth(n,3)) each(output(count())))",
                "#{selfdir}/fixedwidth-n-3.json")
    check_query("all(group(fixedwidth(f,0.5)) each(output(count())))",
                "#{selfdir}/fixedwidth-f-0.5.json")

    # Test xorbit
    check_query("all(group(xorbit(cat(a,b,c),  8)) each(output(count())))", "#{selfdir}/xorbit.8.json")
    check_query("all(group(xorbit(cat(a,b,c), 16)) each(output(count())))", "#{selfdir}/xorbit.16.json")

    # Test md5
    check_query("all(group(md5(cat(a,b,c), 64)) each(output(count())))", "#{selfdir}/md5.64.json")

    # Test different summary classes.
    check_query("all(group(a) max(5) each(max(69) output(count()) each(output(summary()))))", "#{selfdir}/subgroup1.default.json")
    check_query("all(group(a) max(5) each(max(69) output(count()) each(output(summary(normal)))))", "#{selfdir}/subgroup1.json")
    check_query("all(group(a) max(5) each(max(69) output(count()) each(output(summary(summary1)))))", "#{selfdir}/subgroup1.summary1.json")

    # Test aritmetic bitwise expressions (and, or, xor)
    check_query("all(group(and(n, 7)) each(output(count())))", "#{selfdir}/bit.and.json")
    check_query("all(group(or(n, 7)) each(output(count())))", "#{selfdir}/bit.or.json")
    check_query("all(group(xor(n, 7)) each(output(count())))", "#{selfdir}/bit.xor.json")

    # Test aggregators (count, sum, average, xor, hits, max, min, stddev)
    check_query("all(group(a) each(output(count(),sum(n),avg(n),max(n),min(n),xor(n),stddev(n))))",
                "#{selfdir}/allaggr-int.json")
    check_query("all(group(a) each(output(count(),sum(f),avg(f),max(f),min(f),xor(f),stddev(f))))",
                "#{selfdir}/allaggr-float.json")
    check_query("all(group(a) each(output(count(),sum(na),avg(na),max(na),min(na),xor(na),stddev(na))))",
                "#{selfdir}/allaggr-int-array.json")
    check_query("all(group(a) each(output(count(),sum(fa),avg(fa),max(fa),min(fa),xor(fa),stddev(fa))))",
                "#{selfdir}/allaggr-float-array.json")
    check_query("all(group(a) each(output(count(),sum(s),avg(s),min(s),max(s),xor(s),stddev(s))))",
                "#{selfdir}/allaggr-string.json")

    # Test count unique groups (count aggregation on list of groups)
    check_query("all(group(a) output(count()))",
                "#{selfdir}/count-groups-aggr-single-level.json")
    check_query("all(group(lang) output(count()) each(group(n) output(count())))",
                "#{selfdir}/count-groups-aggr-two-levels.json")
    check_query("all(group(a) output(count()) each(group(b) output(count()) each(group(c) output(count()))))",
                "#{selfdir}/count-groups-aggr-three-levels.json")

    # Test uca
    check_query("all(group(lang) order(max(uca(lang, \"sv\"))) each(output(count())))", "#{selfdir}/uca-1.json")
    check_query("all(group(lang) order(max(uca(lang, \"de\"))) each(output(count())))", "#{selfdir}/uca-2.json")
    check_query("all(group(strlen(uca(lang, \"sv\", \"PRIMARY\"))) each(output(count())))", "#{selfdir}/uca-3.json")
    check_query("all(group(strlen(uca(lang, \"sv\", \"TERTIARY\"))) each(output(count())))", "#{selfdir}/uca-4.json")

    # Test mail sort around grouping
    check_query("all(group(predefined(4-n,bucket[-inf,0>,bucket[0],bucket<0,inf])) order(-max(n)) each(output(count()) all(group(n) each(output(count()) each(output(summary(normal)))))))",
                "#{selfdir}/mail-sort-around-int64.json")
    check_query('all(group(predefined(s,bucket(-inf,"bab"),bucket["bab"],bucket<"bab",inf])) order(max(s)) each(output(count()) all(group(s) each(output(count()) each(output(summary(normal)))))))',
                "#{selfdir}/mail-sort-around-string.json")

    # Test aggregators as expressions
    check_query("all(group(lang)  order(-avg(relevance())) each(output(count())))", "#{selfdir}/aggregator-expression1.json")
    check_query("all(group(lang)  order(-avg(relevance()) * count()) each(output(count())))", "#{selfdir}/aggregator-expression2.json")

    # Test for bug 4356109
    check_query("all%28group%28math.atanh%28d%29%29 each%28output%28count%28%29%29%29%29", "#{selfdir}/math.atanh-2.json")

    # TODO handle bool in grouping, and also do so for streaming search.
    check_query("all(group(boool) each(output(count())))", "#{selfdir}/boool.json")

    check_query_default_max("all(group(a)each(each(output(summary()))))", "#{selfdir}/default-max1.json", -1, 1)
    check_query_default_max("all(group(a)each(each(output(summary()))))", "#{selfdir}/default-max2.json", 1, -1)
    check_query_default_max("all(group(a)each(each(output(summary()))))", "#{selfdir}/default-max3.json", 1, 1)
    check_query_default_max("all(group(a)max(2)each(max(2)each(output(summary()))))", "#{selfdir}/default-max4.json", 1, 1)
  end

  # Tests that are known to fail
  def querytest_failing_common
    wait_for_hitcount("query=test&streaming.selection=true", 28, 10)
  end

  def querytest_global_max
    check_query("all(group(a)max(inf)each(max(inf)each(output(summary()))))", "#{selfdir}/global-max-1.json", DEFAULT_TIMEOUT, false)
    check_query("all(group(a)max(inf)each(each(output(summary()))))", "#{selfdir}/global-max-2.json", DEFAULT_TIMEOUT, false)
    check_query("all(group(a)each(max(inf)each(output(summary()))))", "#{selfdir}/global-max-3.json", DEFAULT_TIMEOUT, false)
    check_query("all(group(a)each(each(output(summary()))))", "#{selfdir}/global-max-4.json", DEFAULT_TIMEOUT, false)
    check_query("all(group(a)max(99)each(max(100)each(output(summary()))))", "#{selfdir}/global-max-5.json", DEFAULT_TIMEOUT, false)
    check_query("all(group(a)max(100)each(max(100)each(output(summary()))))", "#{selfdir}/global-max-6.json", DEFAULT_TIMEOUT, false)
  end

  def check_query_default_max(select, file, default_max_groups, default_max_hits)
    full_query = "/?query=sddocname:test&select=#{select}&streaming.selection=true&hits=0&timeout=#{DEFAULT_TIMEOUT}" +
      "&grouping.defaultMaxGroups=#{default_max_groups}&grouping.defaultMaxHits=#{default_max_hits}&groupingSessionCache=false"
    check_fullquery(full_query, file)
  end


  def check_query(select, file, timeout=DEFAULT_TIMEOUT, session_cache=true)
    full_query = "/?query=sddocname:test&select=#{select}&streaming.selection=true&hits=0&timeout=#{timeout}" +
      "&groupingSessionCache=#{session_cache}"
    check_fullquery(full_query, file)
  end

  def check_wherequery(query, select, file, timeout=DEFAULT_TIMEOUT)
    full_query = "/?query=#{query}&select=#{select}&streaming.selection=true&hits=0&timeout=#{timeout}"
    check_fullquery(full_query, file)
  end

  def run_xml_query(select, timeout=DEFAULT_TIMEOUT)
    full_query = "/?query=sddocname:test&select=#{select}&streaming.selection=true&hits=0&format=xml"
    search_with_timeout(timeout, full_query).xml
  end

  def check_fullquery(query, file)
    if (SAVE_RESULT)
      save_result(query, file + '.saved')
      result_data = search_base(query).xmldata
      f = File.new("tmp.txt", "w", 0755)
      f.puts(result_data)
      f.close
      begin
        assert_result(query, file)
        # this prevents the SAVE_RESULT flag from updating the expected
        # results when the changes have no effect on the assert
      rescue Exception => e
        FileUtils.mv("tmp.txt", file)
      end
    else
      assert_result(query, file)
    end
  end

  def runquery(query, timeout)
    result = search_with_timeout(timeout, query)
    return (result == nil || result.json == nil || result.json['root']['errors'])
  end

  def teardown
    stop
  end

end
