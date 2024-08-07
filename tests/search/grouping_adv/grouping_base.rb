# Copyright Vespa.ai. All rights reserved.
module GroupingBase

  SAVE_RESULT = false

  DEFAULT_TIMEOUT = 10

  def setup
    set_owner('bjorncs')
  end

  def can_share_configservers?
    true
  end

  def feed_docs
    feed_and_wait_for_docs('test', 28, :file => "#{selfdir}/docs.json")
  end

  def querytest_common
    wait_for_hitcount('query=test&streaming.selection=true', 28, 10)

    # Test subgrouping.
    check_query('all(group(a) max(5) each(output(count()) each(output(summary(normal)))))',
                'subgroup1')
    check_query('all(group(a) max(5) each(max(69) output(count()) each(output(summary(normal)))))',
                'subgroup1')
    check_query('all(group(a) max(5) each(output(count()) all(group(b) max(5) each(max(69) output(count()) each(output(summary(normal)))))))',
                'subgroup2')
    check_query('all(group(a) max(5) each(output(count()) all(group(b) max(5) each(output(count()) all(group(c) max(5) each(max(69) output(count()) each(output(summary(normal)))))))))',
                'subgroup3')
    check_query('all(group(fixedwidth(n,3)) max(5) each(output(count()) all(group(a) max(2) each(output(count())))))',
                'subgroup4')
    check_query('all(group(fixedwidth(n,3)) max(5) each(output(count()) all(group(a) max(2) each(output(count())))))',
                'subgroup5')
    check_query('all(group(fixedwidth(n,3)) max(5) each(output(count()) all(group(a) max(2) each(max(1) output(count()) each(output(summary(normal)))))))',
                'subgroup6')

    # Test orderby
    check_query('all(group(a) order(-sum(from)) each(output(count())))',
                'orderby1')
    check_query('all(group(a) order(sum(from)) each(output(count())))',
                'orderby-1')

    check_query('all(group(a) max(2) order(-sum(from)) precision(3) each(output(count())))',
                'orderby1-m1')
    check_query('all(group(a) max(2) order(sum(from)) precision(3) each(output(count())))',
                'orderby-1-m1')
    check_query('all(group(a) max(2) order(-count()) each(output(count())))',
                'orderby2')

    # Test combination
    check_query('all(group(a) max(2) order(-count()) each(output(count())) as(foo) each(output(max(b))) as(bar))',
                'combination-1')

    # Test limit and precision
    topn_json = run_query('all(all(group(a)each(output(count()))))')
    sum=0
    for g in topn_json['root']['children'][0]['children'][0]['children']
      sum += g['fields']['count()']
    end
    puts "sum = #{sum}"
    assert(sum == 28)
    topn_json = run_query('all(max(2)all(group(a)each(output(count()))))')
    sum=0
    for g in topn_json['root']['children'][0]['children'][0]['children']
      sum += g['fields']['count()']
    end
    puts "sum = #{sum}"
    assert(sum <= 2*8)

    check_query('all(group(a) max(2) each(output(count())))',
                'constraint2')
    check_query('all(group(a) max(2) precision(10) each(output(count())))',
                'constraint3')

    # Test time.(year,day,month,yday,wday,hour,min,sec)
    check_query('all(group(time.year(from)) each(output(count()) ))',
                'time.year')
    check_query('all(group(time.monthofyear(from)) each(output(count()) ))',
                'time.month')
    check_query('all(group(time.hourofday(from)) each(output(count()) ))',
                'time.hour')
    check_query('all(group(time.secondofminute(from)) each(output(count()) ))',
                'time.second')
    check_query('all(group(time.minuteofhour(from)) each(output(count()) ))',
                'time.minute')
    check_query('all(group(time.dayofmonth(from)) each(output(count()) ))',
                'time.mday')
    check_query('all(group(time.dayofyear(from)) each(output(count()) ))',
                'time.yday')
    check_query('all(group(time.dayofweek(from)) each(output(count()) ))',
                'time.wday')

    # Test relevance
    check_query('all(group(a) each(output(count(),sum(mod(relevance(),100000))) ))',
                'relevance')

    # Test cat
    check_query('all(group(cat(a,b,c)) each(output(count())))',
                'cat')

    # Test zcurve
    check_query('all(group(zcurve.x(to)) each(output(count())))',
                'zcurve.x')
    check_query('all(group(zcurve.y(to)) each(output(count())))',
                'zcurve.y')

    # Test aritmetic expressions (add, sub, mul, div, mod)
    check_query('all(group(add(f,f)) each(output(count())))', 'add-ff')
    check_query('all(group(add(n,f)) each(output(count())))', 'add-nf')
    check_query('all(group(mul(2,f)) each(output(count())))', 'mul-2f')
    check_query('all(group(mul(n,f)) each(output(count())))', 'mul-nf')
    check_query('all(group(sub(f,f)) each(output(count())))', 'sub-ff')
    check_query('all(group(sub(f,n)) each(output(count())))', 'sub-fn')
    check_query('all(group(div(f,n)) each(output(count())))', 'div-fn')
    check_query('all(group(div(f,f)) each(output(count())))', 'div-ff')
    check_query('all(group(mod(f,n)) each(output(count())))', 'mod-fn')
    check_query('all(group(mod(n,f)) each(output(count())))', 'mod-nf')
    check_query('all(group(mod(f,f)) each(output(count())))', 'mod-2f')

    # Test alternative ranking.
    check_query('all(group(a) order(sum(relevance()),-count()) each(output(count(),sum(mod(relevance(),100000))) ))',
                'rank-relevance-count')

    # Test strcat
    check_query('all(group(strcat(a,b,c)) each(output(count())))', 'strcat')
    check_query('all(group(strcat(a,n,d)) each(output(count())))', 'strcat-int-double')
    check_query('all(group(strcat(a,n,na)) each(output(count())))', 'strcat-array')
    check_query('all(group(strcat(a,n,nw)) each(output(count())))', 'strcat-ws')
    # Test strlen
    check_query('all(group(strlen(strcat(a,b,c))) each(output(count())))', 'strlen')

    check_query('all(group(tostring(f)) each(output(count())))', 'tostring-f')
    check_query('all(group(tostring(n)) each(output(count())))', 'tostring-n')
    check_query('all(group(tostring(sf)) each(output(count())))', 'tostring-sf')
    check_query('all(group(tolong(f)) each(output(count())))', 'tolong-f')
    check_query('all(group(tolong(n)) each(output(count())))', 'tolong-n')
    check_query('all(group(tolong(sf)) each(output(count())))', 'tolong-sf')
    check_query('all(group(todouble(d)) each(output(count())))', 'todouble-d')
    check_query('all(group(todouble(f)) each(output(count())))', 'todouble-f')
    check_query('all(group(todouble(n)) each(output(count())))', 'todouble-n')
    check_query('all(group(todouble(sf)) each(output(count())))', 'todouble-sf')

    # Test math operations
    check_query('all(group(math.exp(d)) each(output(count())))', 'math.exp')
    check_query('all(group(math.log(d)) each(output(count())))', 'math.log')
    check_query('all(group(math.log1p(d)) each(output(count())))', 'math.log1p')
    check_query('all(group(math.log10(d)) each(output(count())))', 'math.log10')
    check_query('all(group(math.sin(d)) each(output(count())))', 'math.sin')
    check_query('all(group(math.asin(d)) each(output(count())))', 'math.asin')
    check_query('all(group(math.cos(d)) each(output(count())))', 'math.cos')
    check_query('all(group(math.acos(d)) each(output(count())))', 'math.acos')
    check_query('all(group(math.tan(d)) each(output(count())))', 'math.tan')
    check_query('all(group(math.atan(d)) each(output(count())))', 'math.atan')
    check_query('all(group(math.sqrt(d)) each(output(count())))', 'math.sqrt')
    check_query('all(group(math.sinh(d)) each(output(count())))', 'math.sinh')
    check_query('all(group(math.asinh(d)) each(output(count())))', 'math.asinh')
    check_query('all(group(math.cosh(d)) each(output(count())))', 'math.cosh')
    check_query('all(group(math.acosh(d)) each(output(count())))', 'math.acosh')
    check_query('all(group(math.tanh(d)) each(output(count())))', 'math.tanh')
    check_query('all(group(math.atanh(d/10)) each(output(count())))', 'math.atanh')
    check_query('all(group(math.cbrt(d)) each(output(count())))', 'math.cbrt')
    check_query('all(group(math.pow(d,d)) each(output(count())))', 'math.pow')
    check_query('all(group(math.hypot(d,d)) each(output(count())))', 'math.hypot')

    # Test length(NumElemFunctionNode
    check_query('all(group(size(na)) each(output(count())))', 'length-a')
    check_query('all(group(size(nw)) each(output(count())))', 'length-w')

    # Test predefined buckets
    check_query('all(group(predefined(n,bucket(1,3),bucket(6,9))) each(output(count())))', 'predef1')
    check_query('all(group(predefined(f,bucket(-inf,3),bucket(6,9))) each(output(count())))', 'predef1.2')
    check_query('all(group(predefined(f,bucket(1.0,3.0),bucket(6.0,9.0))) each(output(count())))',
                'predef2')
    check_query("all(group(predefined(s,bucket(\"ab\",\"abc\"),bucket(\"abc\",\"bc\"))) each(output(count())))",
                'predef3')
    check_query('all(group(predefined(d, bucket(-inf, 0.0), bucket(0.0, inf))) each(output(count())))',
                'predef4')

    # Test fixedwidth buckets
    check_query('all(group(fixedwidth(n,3)) each(output(count())))',
                'fixedwidth-n-3')
    check_query('all(group(fixedwidth(f,0.5)) each(output(count())))',
                'fixedwidth-f-0.5')

    # Test xorbit
    check_query('all(group(xorbit(cat(a,b,c),  8)) each(output(count())))', 'xorbit.8')
    check_query('all(group(xorbit(cat(a,b,c), 16)) each(output(count())))', 'xorbit.16')

    check_query('all(group(cat("",c)) each(output(count(), max(cat("",nb)))))', 'cat-array')

    # Test md5
    check_query('all(group(md5(cat(a,b,c), 64)) each(output(count())))', 'md5.64')

    # Test different summary classes.
    check_query('all(group(a) max(5) each(max(69) output(count()) each(output(summary()))))', 'subgroup1.default')
    check_query('all(group(a) max(5) each(max(69) output(count()) each(output(summary(normal)))))', 'subgroup1')
    check_query('all(group(a) max(5) each(max(69) output(count()) each(output(summary(summary1)))))', 'subgroup1.summary1')

    # Test aritmetic bitwise expressions (and, or, xor)
    check_query('all(group(and(n, 7)) each(output(count())))', 'bit.and')
    check_query('all(group(or(n, 7)) each(output(count())))', 'bit.or')
    check_query('all(group(xor(n, 7)) each(output(count())))', 'bit.xor')

    # Test aggregators (count, sum, average, xor, hits, max, min, stddev)
    check_query('all(group(a) each(output(count(),sum(n),avg(n),max(n),min(n),xor(n),stddev(n))))',
                'allaggr-int')
    check_query('all(group(a) each(output(count(),sum(f),avg(f),max(f),min(f),xor(f),stddev(f))))',
                'allaggr-float')
    check_query('all(group(a) each(output(count(),sum(na),avg(na),max(na),min(na),xor(na),stddev(na))))',
                'allaggr-int-array')
    check_query('all(group(a) each(output(count(),sum(fa),avg(fa),max(fa),min(fa),xor(fa),stddev(fa))))',
                'allaggr-float-array')
    check_query('all(group(a) each(output(count(),sum(s),avg(s),min(s),max(s),xor(s),stddev(s))))',
                'allaggr-string')

    # Test count unique groups (count aggregation on list of groups)
    check_query('all(group(a) output(count()))',
                'count-groups-aggr-single-level')
    check_query('all(group(lang) output(count()) each(group(n) output(count())))',
                'count-groups-aggr-two-levels')
    check_query('all(group(a) output(count()) each(group(b) output(count()) each(group(c) output(count()))))',
                'count-groups-aggr-three-levels')

    # Test uca
    check_query("all(group(lang) order(max(uca(lang, \"sv\"))) each(output(count())))", 'uca-1')
    check_query("all(group(lang) order(max(uca(lang, \"de\"))) each(output(count())))", 'uca-2')
    check_query("all(group(strlen(uca(lang, \"sv\", \"PRIMARY\"))) each(output(count())))", 'uca-3')
    check_query("all(group(strlen(uca(lang, \"sv\", \"TERTIARY\"))) each(output(count())))", 'uca-4')

    # Test mail sort around grouping
    check_query('all(group(predefined(4-n,bucket[-inf,0>,bucket[0],bucket<0,inf])) order(-max(n)) each(output(count()) all(group(n) each(output(count()) each(output(summary(normal)))))))',
                'mail-sort-around-int64')
    check_query('all(group(predefined(s,bucket(-inf,"bab"),bucket["bab"],bucket<"bab",inf])) order(max(s)) each(output(count()) all(group(s) each(output(count()) each(output(summary(normal)))))))',
                'mail-sort-around-string')

    # Test aggregators as expressions
    check_query('all(group(lang)  order(-avg(relevance())) each(output(count())))', 'aggregator-expression1')
    check_query('all(group(lang)  order(-avg(relevance()) * count()) each(output(count())))', 'aggregator-expression2')

    # Test for bug 4356109
    check_query('all(group(math.atanh(d)) each(output(count())))', 'math.atanh-2')

    # TODO handle bool in grouping, and also do so for streaming search.
    check_query('all(group(boool) each(output(count())))', 'boool')

    check_query_default_max('all(group(a)each(each(output(summary()))))', 'default-max1', -1, 1)
    check_query_default_max('all(group(a)each(each(output(summary()))))', 'default-max2', 1, -1)
    check_query_default_max('all(group(a)each(each(output(summary()))))', 'default-max3', 1, 1)
    check_query_default_max('all(group(a)max(2)each(max(2)each(output(summary()))))', 'default-max4', 1, 1)

    check_query("all(group(a)alias(myalias,count())each(output($myalias)))", 'alias-1')
    check_query("all(group(a)order($myalias=count())each(output($myalias)))", 'alias-2')
  end

  # Tests that are known to fail
  def querytest_failing_common
    wait_for_hitcount('query=test&streaming.selection=true', 28, 10)
  end

  def querytest_global_max
    check_query('all(group(a)max(inf)each(max(inf)each(output(summary()))))', 'global-max-1', DEFAULT_TIMEOUT, false)
    check_query('all(group(a)max(inf)each(each(output(summary()))))', 'global-max-2', DEFAULT_TIMEOUT, false)
    check_query('all(group(a)each(max(inf)each(output(summary()))))', 'global-max-3', DEFAULT_TIMEOUT, false)
    check_query('all(group(a)each(each(output(summary()))))', 'global-max-4', DEFAULT_TIMEOUT, false)
    check_query('all(group(a)max(99)each(max(100)each(output(summary()))))', 'global-max-5', DEFAULT_TIMEOUT, false)
    check_query('all(group(a)max(100)each(max(100)each(output(summary()))))', 'global-max-6', DEFAULT_TIMEOUT, false)
  end

  def querytest_groups_for_default_value(streaming=false)
    classifier = streaming ? 'streaming' : 'indexed'
    # Test default group for singlevalue attributes
    check_query_default_value("all(group(n)each(each(output(summary()))))", "#{classifier}-group-attribute-int")
    check_query_default_value("all(group(to)each(each(output(summary()))))", "#{classifier}-group-attribute-long")
    check_query_default_value("all(group(f)each(each(output(summary()))))", "#{classifier}-group-attribute-float")
    check_query_default_value("all(group(d)each(each(output(summary()))))", "#{classifier}-group-attribute-double")
    check_query_default_value("all(group(s)each(each(output(summary()))))", "#{classifier}-group-attribute-string")
    check_query_default_value("all(group(boool)each(each(output(summary()))))", "#{classifier}-group-attribute-bool")
    check_query_default_value("all(group(by)each(each(output(summary()))))", "#{classifier}-group-attribute-byte")

    # Test default group for expression over attributes
    check_query_default_value("all(group(add(n,1))each(output(count())))", "#{classifier}-group-add")
    check_query_default_value("all(group(mul(n,3))each(output(count())))", "#{classifier}-group-mul")
    check_query_default_value("all(group(sub(n,1))each(output(count())))", "#{classifier}-group-sub")
    check_query_default_value("all(group(div(f,2))each(output(count())))", "#{classifier}-group-div")
    check_query_default_value("all(group(mod(n,2))each(output(count())))", "#{classifier}-group-mod")
    check_query_default_value("all(group(cat(a,b,c))each(output(count())))", "#{classifier}-group-cat")
    check_query_default_value("all(group(strcat(a,b,c))each(output(count())))", "#{classifier}-group-strcat")
    check_query_default_value("all(group(tostring(n))each(output(count())))", "#{classifier}-group-tostring")
    check_query_default_value("all(group(tolong(f))each(output(count())))", "#{classifier}-group-tolong")
    check_query_default_value("all(group(todouble(n))each(output(count())))", "#{classifier}-group-todouble")
    check_query_default_value("all(group(math.sin(f))each(output(count())))", "#{classifier}-group-math-sin")
    check_query_default_value("all(group(math.pow(n,2))each(output(count())))", "#{classifier}-group-math-pow")
    check_query_default_value("all(group(size(na))each(output(count())))", "#{classifier}-group-size-array")
    check_query_default_value("all(group(size(nw))each(output(count())))", "#{classifier}-group-size-weighed-set")
    check_query_default_value("all(group(predefined(4-n,bucket(-inf,3),bucket(3,inf)))each(output(count())))",
                "#{classifier}-group-predefined-buckets")
    check_query_default_value("all(group(fixedwidth(n,3))each(output(count())))", "#{classifier}-group-fixedwidth")
    check_query_default_value("all(group(xorbit(n,8))each(output(count())))", "#{classifier}-group-xor")
    check_query_default_value("all(group(md5(n,64))each(output(count())))", "#{classifier}-group-md5")
    check_query_default_value("all(group(and(n,7))each(output(count())))", "#{classifier}-group-and")
    check_query_default_value("all(group(time.year(from))each(output(count())))", "#{classifier}-group-time-year")
    check_query_default_value("all(group(time.dayofweek(from))each(output(count())))", "#{classifier}-group-time-dayofweek")
    check_query_default_value("all(group(zcurve.x(to))each(output(count())))", "#{classifier}-group-zcurve-x")
    check_query_default_value("all(group(strlen(uca(lang,\"sv\",\"PRIMARY\")))each(output(count())))", "#{classifier}-group-strlen-uca")

    # Test aggregator on attributes having default value
    check_query_default_value("all(group(n)each(output(sum(f))each(output(summary()))))", "#{classifier}-aggregator-sum")
    check_query_default_value("all(group(f)each(output(min(n))each(output(summary()))))", "#{classifier}-aggregator-min")
    check_query_default_value("all(group(f)each(output(max(n))each(output(summary()))))", "#{classifier}-aggregator-max")
    check_query_default_value("all(group(f)each(output(avg(n))each(output(summary()))))", "#{classifier}-aggregator-avg")
    check_query_default_value("all(group(f)each(output(xor(to))each(output(summary()))))", "#{classifier}-aggregator-xor")
    check_query_default_value("all(group(f)each(output(stddev(n))each(output(summary()))))", "#{classifier}-aggregator-stddev")
  end

  def check_query_default_max(select, file, default_max_groups, default_max_hits)
    full_query = "/?query=sddocname:test&select=#{select}&streaming.selection=true&hits=0&timeout=#{DEFAULT_TIMEOUT}" +
      "&grouping.defaultMaxGroups=#{default_max_groups}&grouping.defaultMaxHits=#{default_max_hits}&groupingSessionCache=false"
    check_fullquery(full_query, file)
  end


  def check_query(select, file, timeout=DEFAULT_TIMEOUT, session_cache=true, rank_profile="default")
    full_query = "/?query=sddocname:test&select=#{select}&streaming.selection=true&hits=0&timeout=#{timeout}" +
      "&groupingSessionCache=#{session_cache}&ranking.profile=#{rank_profile}"
    check_fullquery(full_query, file)
  end

  def check_query_default_value(select, file)
    check_query(select, "default-values/#{file}", DEFAULT_TIMEOUT, true, "default-values")
  end

  def check_wherequery(query, select, file, timeout=DEFAULT_TIMEOUT)
    full_query = "/?query=#{query}&select=#{select}&streaming.selection=true&hits=0&timeout=#{timeout}"
    check_fullquery(full_query, file)
  end

  def run_query(select, timeout=DEFAULT_TIMEOUT)
    full_query = "/?query=sddocname:test&select=#{select}&streaming.selection=true&hits=0"
    search_with_timeout(timeout, full_query).json
  end

  def check_fullquery(query, localfile)
    puts "check #{query} with #{localfile}"
    file = selfdir + 'answers/' + localfile + '.json'
    if (SAVE_RESULT)
      save_result(query, file + '.saved')
      result_data = search_base(query).xmldata
      f = File.new('tmp.txt', 'w', 0755)
      f.puts(result_data)
      f.close
      begin
        assert_result(query, file)
        # this prevents the SAVE_RESULT flag from updating the expected
        # results when the changes have no effect on the assert
      rescue Exception => e
        FileUtils.mv('tmp.txt', file)
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
