# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'test/unit'

require 'performance/datasetmanager'
require 'test/ds_fetcher.rb'


class DatasetManagerTest < Test::Unit::TestCase

  def test_filter
    fetcher = DSFetcher.new(Dir.glob(File.join(File.dirname(__FILE__), 'data', '*.xml')))
    assert_equal(3, fetcher.fetch.size)

    mgr = DatasetManager.new({:x => 'clients', :y => 'qps',
                               :filter => {
                                 'clients' => [1]
                               }},
                             fetcher)
    assert_equal(1, mgr.datasets[0].size)
    mgr2 = DatasetManager.new({:x => 'clients', :y => 'qps',
                                :filter => {
                                  'clients' => [1,2]
                                }},
                              fetcher)
    assert_equal(2, mgr2.datasets[0].size)
  end

  def test_split_version
    manager = DatasetManager.new({}, DSFetcher.new([]))
    split = manager.split_version('5.10.130-123')
    assert_equal([5, 10, 130, 123], split)
  end

end
