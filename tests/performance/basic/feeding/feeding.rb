# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'performance_test'
require 'app_generator/search_app'
require 'performance/fbench'
require 'pp'


class BasicFeeding < PerformanceTest

  def initialize(*args)
    super(*args)
    @app = selfdir + 'feedingapp'
  end

  def prepare
    super
  end

  def setup
    super
    set_owner("bergum")
    deploy_expand_vespa_home(@app)
    start
    vespa_destination_start
  end

  def doc_template(type)
    '{ "put": "id:test:' + type + '::$seq()", "fields": { "text": "$words(100)" } }'
  end

  def my_run_feeder(template, key, feed_params)
    feed_params = feed_params.merge({:template => template, :count => 500000})
    run_template_feeder(params: feed_params, :count => 100000)

    profiler_start
    run_template_feeder(fillers: [parameter_filler("legend", key)], params: feed_params)
    profiler_report(key)
  end

  def test_feeding_performance_simple
    set_description("Feeds documents through empty docproc chain without any linguistic indexing to dev/null")
    feed_params = {:numthreads => 8, :route => '"stateless/chain.empty null/default"'}

    my_run_feeder(doc_template("text1"), "test_feeding_performance_simple", feed_params)
  end

  def test_feeding_performance_simpler
    set_description("Feeds documents directly to dev/null")
    feed_params = {:numthreads => 8, :route => '"null/default"'}

    my_run_feeder(doc_template("text1"), "test_feeding_performance_simpler", feed_params)
  end

  def test_feeding_performance_simple_maxpending
    set_description("Feeds documents using maxpending instead of dynamic policy empty docproc chain without any linguistic indexing to dev/null")
    feed_params = {:numthreads => 8, :route => '"stateless/chain.empty null/default"' ,:maxpending => 400}

    my_run_feeder(doc_template("text1"), "test_feeding_performance_simple_maxpending", feed_params)
  end


  def test_feeding_performance_simple_indexing
    set_description("Feeds documents through empty docproc chain with linguistic indexing to dev/null")
    feed_params = {:numthreads => 3, :route => '"stateless/chain.emptywindexing null/default"'}

    my_run_feeder(doc_template("text1"), "test_feeding_performance_simple_indexing", feed_params)
  end

  def test_feeding_performance_simple_indexing_persistence
    set_description("Feeds documents through built-in indexing chain into persistence store backed by proton")
    feed_params = {:numthreads => 3, :route => '"search-index"'}

    my_run_feeder(doc_template("text1"), "test_feeding_performance_simple_indexing_persistence", feed_params)
  end

  def test_feeding_performance_simple_persistence_streaming
    set_description("Feeds documents directly into persistence store with streaming mode")
    feed_params = {:numthreads => 3, :route => '"search-direct"'}

    my_run_feeder(doc_template("text2"), "test_feeding_performance_simple_persistence_streaming", feed_params)
  end

  def test_feeding_performance_emptychain_persistence_streaming
    set_description("Feeds documents through no-op indexing into persistence store with streaming mode")
    feed_params = {:numthreads => 3}

    my_run_feeder(doc_template("text2"), "test_feeding_performance_emptychain_persistence_streaming", feed_params)
  end

  def test_feeding_performance_simple_persistence_proton
    set_description("Feeds documents directly into persistence store backed by proton engine")
    feed_params = {:numthreads => 3, :route => '"search-direct"'}

    my_run_feeder(doc_template("text1"), "test_feeding_performance_simple_persistence_proton", feed_params)
  end

  def teardown
    super
  end

end
