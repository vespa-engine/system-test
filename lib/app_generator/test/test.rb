# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'test/unit'
require 'app_generator/search_app'
require 'app_generator/http'
require_relative 'assertion_utils'

class SearchAppGenTest < Test::Unit::TestCase

  include AssertionUtils

  def file(name)
    File.join(File.dirname(__FILE__), "#{name}")
  end

  def create_default
    SearchApp.new.sd("sd")
  end

  def create_complex
    SearchApp.new.sd("sd1").sd("sd2").sd("sd3").
      cluster_name("storage").num_parts(4).redundancy(3).
      enable_document_api.
      config(ConfigOverride.new("stor-distribution").
             add("ready_copies", 2))
  end

  def verify(expect, app)
    actual = app.services_xml
    File.open(file(expect + '.actual'), 'w') do |f|
      f.puts actual
    end
    assert(system("diff -u #{file expect} #{file expect + '.actual'}"))
  end

  # test basic setup without modifications
  def test_default
    verify('default.xml', create_default.enable_document_api)
  end

  def test_default_streaming
    verify('default_streaming.xml', create_default.streaming.enable_document_api)
  end

  # test setup with bells and whistles
  def test_complex
    verify('complex.xml', create_complex)
  end

  def assert_equal(exp, actual)
    assert(exp == actual, "Expected '#{exp}', but was '#{actual}'")
  end

  def test_config_values
    actual = ConfigValues.new.add(ConfigValue.new("key1", "value1")).
             add("key2", "value2").to_xml
    expected = '<key1>value1</key1>
                <key2>value2</key2>'
    assert_substring_ignore_whitespace(actual, expected)
  end

  def test_provider
    actual = SearchApp.new.
             search_chain(Provider.new("local-provider", "local").
                          cache_size("100M").
             cluster("search")).services_xml
    expected_substr = '
      <search>
        <provider cachesize="100M" cluster="search" excludes="" id="local-provider" type="local" />
      </search>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_handler
    actual = SearchApp.new.
             handler("foo").
             handler("bar", ConfigOverride.new("baz").add("qux", "quux")).
             services_xml
    expected_substr = '
      <container id="default" version="1.0">
        <search />
        <document-processing />
        <handler id="foo" />
        <handler id="bar">
          <config name="baz">
            <qux>quux</qux>
          </config>
        </handler>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_routing
    app = SearchApp.new.
          routingtable(RoutingTable.new.
                       add(Hop.new("hop name", "elastic-selector")).
                       add(Hop.new("hop name2", "elastic-selector2").
                           recipient("session2")).
                       add(Route.new("route name", "hops")))
    actual = app.elastic.services_xml
    expected_substr = '
      <routing version="1.0">
        <routingtable protocol="document">
          <hop name="hop name" selector="elastic-selector" />
          <hop name="hop name2" selector="elastic-selector2">
            <recipient session="session2" />
          </hop>
          <route hops="hops" name="route name" />
        </routingtable>
      </routing>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_configservers
    actual = SearchApp.new.
             configserver("node1").configserver("node2").
             services_xml
    expected_substr = '
      <configservers>
        <configserver hostalias="node1" />
        <configserver hostalias="node2" />
      </configservers>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_monitoring
    actual = SearchApp.new.monitoring("name", "42").services_xml
    expected_substr = '<monitoring interval="42" systemname="name" />'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_search_clusters
    actual = SearchApp.new.
             cluster(SearchCluster.new("foo").sd("fo/ba/sd1.sd").sd("sd2.sd").
                     visibility_delay(5).selection("doc_sel").
                     flush_on_shutdown(true).
                     redundancy(3).
                     ready_copies(2).
                     num_parts(3).
                     threads_per_search(2).
                     allowed_lid_bloat(3).
                     allowed_lid_bloat_factor(0.7)).
             services_xml

    expected_substr = '
      <content id="foo" version="1.0">
        <redundancy>3</redundancy>
        <config name="vespa.config.search.core.proton">
          <numthreadspersearch>2</numthreadspersearch>
          <initialize>
            <threads>16</threads>
          </initialize>
          <lidspacecompaction>
            <allowedlidbloat>3</allowedlidbloat>
	    <allowedlidbloatfactor>0.7</allowedlidbloatfactor>
          </lidspacecompaction>
          <hwinfo>
            <disk>
              <shared>true</shared>
              <writespeed>150.0</writespeed>
            </disk>
          </hwinfo>
        </config>
        <documents selection="doc_sel">
          <document-processing cluster="default" />
          <document mode="index" type="sd1" />
          <document mode="index" type="sd2" />
        </documents>
        <group>
          <node hostalias="node1" distribution-key="0" />
          <node hostalias="node1" distribution-key="1" />
          <node hostalias="node1" distribution-key="2" />
        </group>
        <engine>
          <proton>
            <visibility-delay>5</visibility-delay>
            <searchable-copies>2</searchable-copies>
            <flush-on-shutdown>true</flush-on-shutdown>
          </proton>
        </engine>
     </content>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_can_include_node_ratio_per_group_tuning_parameter
    actual = SearchApp.new.
             cluster(SearchCluster.new("foo").min_node_ratio_per_group(0.75)).
             services_xml

    expected_substr = '
      <content id="foo" version="1.0">
        <tuning>
          <min-node-ratio-per-group>0.75</min-node-ratio-per-group>
        </tuning>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_indexingclustername
    actual = SearchApp.new.
             cluster(SearchCluster.new("foo").sd("sd").indexing("default")).
             services_xml
    expected_substr = '<document-processing cluster="default" />'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_indexingclustername_indexingchain
    actual = SearchApp.new.
             cluster(SearchCluster.new("foo").sd("sd").indexing("default").indexing_chain("banana")).
             services_xml
    expected_substr = '<document-processing chain="banana" cluster="default" />'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_multiple_container_clusters
    actual = SearchApp.new.
        qrserver(QrserverCluster.new("foo")).
        qrserver(QrserverCluster.new("bar")).
        services_xml

    expected_substr = '
      <container id="foo" version="1.0">
        <search />
        <nodes>
          <node hostalias="node1" />
        </nodes>
      </container>
      <container baseport="4090" id="bar" version="1.0">
        <search />
        <nodes>
          <node hostalias="node1" />
        </nodes>
      </container>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_multiple_qrserver_clusters
    actual = SearchApp.new.
        qrserver(QrserverCluster.new("foo")).
        qrserver(QrserverCluster.new("bar")).
        services_xml

    expected_substr = '
 <container id="foo" version="1.0">
      <search />
      <nodes>
        <node hostalias="node1" />
      </nodes>
    </container>
    <container baseport="4090" id="bar" version="1.0">
      <search />
      <nodes>
        <node hostalias="node1" />
      </nodes>
    </container>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_multiple_slobroks
    actual = SearchApp.new.slobrok("node1").slobrok("node2").
             services_xml
    expected_substr = '
      <slobroks>
        <slobrok hostalias="node1" />
        <slobrok hostalias="node2" />
      </slobroks>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_multiple_cluster_controllers
    actual = SearchApp.new.admin(Admin.new.
             clustercontroller("node1").clustercontroller("node2")).
             services_xml
    expected_substr = '
      <cluster-controllers>
        <cluster-controller hostalias="node1" />
        <cluster-controller hostalias="node2" />
      </cluster-controllers>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_search_and_storage
   actual = SearchApp.new.
	storage(StorageCluster.new("storage", 3).
	        group(NodeGroup.new(nil, nil).
 	              distribution("*").
	              group(NodeGroup.new(0, "rack 0").
                            default_nodes(2, 0)).
	              group(NodeGroup.new(1, "rack 1").
                            default_nodes(2, 2)))).
	services_xml
   expected_substr = '
     <content id="storage" version="1.0">'
   assert_substring_ignore_whitespace(actual, expected_substr)

   expected_substr = '
       <redundancy>3</redundancy>
       <group>
         <distribution partitions="*" />
         <group distribution-key="0" name="rack 0">
           <node hostalias="node1" distribution-key="0" />
           <node hostalias="node1" distribution-key="1" />
         </group>
         <group distribution-key="1" name="rack 1">
           <node hostalias="node1" distribution-key="2" />
           <node hostalias="node1" distribution-key="3" />
         </group>
       </group>
       <engine>
         <proton />
       </engine>
     </content>'
     assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_tuning
    actual = SearchApp.new.cluster(SearchCluster.new.
                                   tune_searchnode({:tooning => 7.8}).
                                   tune_searchnode({:foo => {:bar => 10, :baz => 20.5}})).
                                   services_xml
    expected_substr = '
      <engine>
        <proton>
          <searchable-copies>1</searchable-copies>
          <tuning>
            <searchnode>
              <tooning>7.8</tooning>
              <foo>
                <bar>10</bar>
                <baz>20.5</baz>
              </foo>
            </searchnode>
          </tuning>
        </proton>
      </engine>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_plugin_config
    app = SearchApp.new.
      cluster(SearchCluster.new("foo").sd("sd1.sd").
              config(ConfigOverride.new("content-cfg").add("bar", 2)))

    actual_elastic = app.services_xml
    actual_streaming = app.streaming.services_xml

    expected_substr_content = '
    <config name="content-cfg">
      <bar>2</bar>
    </config>'
    assert_substring_ignore_whitespace(actual_streaming, expected_substr_content)
    assert_substring_ignore_whitespace(actual_elastic, expected_substr_content)
  end

  def test_admin_metrics
    actual = SearchApp.new.
        admin_metrics(Metrics.new.
                          consumer(Consumer.new('my-consumer').
                                       metric_set(MetricSet.new('my-set')).
                                       metric(Metric.new('my-metric')))).services_xml
    expected = '
    <admin version="2.0">
      <adminserver hostalias="node1" />
      <metrics>
        <consumer id="my-consumer">
          <metric-set id="my-set" />
          <metric id="my-metric" />
        </consumer>
      </metrics>'
    assert_substring_ignore_whitespace(actual, expected)
  end

  def test_adminserver_hostalias
    actual = SearchApp.new.
      admin(Admin.new.adminserver(AdminServer.new('node2'))).services_xml
    expected = '<adminserver hostalias="node2" />'
    assert_substring_ignore_whitespace(actual, expected)
  end

  def test_cluster_controller_tuning_in_search_app
    actual = SearchApp.new.
      sd('music').cluster_name('storage').
      storage(StorageCluster.new.transition_time(5)).services_xml
    expected = '
      <tuning>
        <cluster-controller>
          <transition-time>5</transition-time>
        </cluster-controller>
      </tuning>'
    assert_substring_ignore_whitespace(actual, expected)
    expected = '<document mode="index" type="music" />'
    assert_substring_ignore_whitespace(actual, expected)
  end

  def test_qrsnode_config
    actual = SearchApp.new.qrserver(QrserverCluster.new.
        node(:config => ConfigOverride.new("cfg").add("val", 1))).
      services_xml
    expected_substr = '
    <container id="default" version="1.0">
      <search />
      <nodes>
        <node hostalias="node1">
          <config name="cfg">
            <val>1</val>
          </config>
        </node>
      </nodes>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_container_config
    actual = SearchApp.new.container(Container.new.
                                     config(ConfigOverride.new("cfg").add("val", 1))).services_xml
    expected = '
    <container id="default" version="1.0">
      <config name="cfg">
        <val>1</val>
      </config>
      <nodes'
    assert_substring_ignore_whitespace(actual, expected)
  end

  def test_nodes_config
    app = SearchApp.new.
      cluster(SearchCluster.new.
              group(NodeGroup.new(0, nil).
                    cpu_socket_affinity(true).
                    config(ConfigOverride.new("cfg1").add("key1", "val1")).
                           node(NodeSpec.new("node1", 0).
                                config(ConfigOverride.new("cfg2").
                                       add("key2", "val2")))))
    actual_elastic = app.services_xml
    expected_elastic = '
    <group cpu-socket-affinity="true">
      <config name="cfg1">
        <key1>val1</key1>
      </config>
      <node hostalias="node1" distribution-key="0">
        <config name="cfg2">
          <key2>val2</key2>
        </config>
      </node>
    </group>'
    assert_substring_ignore_whitespace(actual_elastic, expected_elastic)
  end

  def test_content_cluster_config
    actual = SearchApp.new.
             cluster(SearchCluster.new("foo").sd("bar").
                     config(ConfigOverride.new("cfg").add("val", 1))).
             services_xml
    expected_substr = '
    <content id="foo" version="1.0">
      <redundancy>1</redundancy>
      <config name="cfg">
        <val>1</val>
      </config>
      <config name="vespa.config.search.core.proton">
        <numthreadspersearch>4</numthreadspersearch>
        <initialize>
          <threads>16</threads>
        </initialize>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_searchchains_config
    actual = SearchApp.new.
      search_chains_config(ConfigOverride.new("cfg").add("val", 1)).
      services_xml
    expected_substr = '
      <search>
        <config name="cfg">
          <val>1</val>
        </config>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_searchchain_config
    actual = SearchApp.new.
      search_chain(SearchChain.new.config(ConfigOverride.new("cfg").add("val", 1))).
      services_xml
    expected_substr = '
      <search>
        <chain id="default" inherits="vespa">
          <config name="cfg">
            <val>1</val>
          </config>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_chain_in_search
    actual = SearchApp.new.
        search_chain(SearchChain.new()).
        services_xml
    expected_substr = '
    <container id="default" version="1.0">
      <search>
        <chain id="default" inherits="vespa" />
      </search>
      <document-processing />
      <nodes>
        <node hostalias="node1" />
      </nodes>
    </container>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_searcher_class_name
    actual = Searcher.new("foo").klass("bar").to_xml;
    expected_substr = '<searcher class="bar" id="foo"'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_container_jvm_options
    actual = SearchApp.new.qrserver(
               QrserverCluster.new.jvmoptions('-Option')).services_xml
    expected_substr = '
      <container id="default" version="1.0">
      <search />
          <nodes>
            <jvm options="-Option" />
            <node hostalias="node1" />
        </nodes>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_recursive_config_value
    actual = ConfigValue.new("outer", ConfigValue.new("inner", "value")).
      to_xml(" ")
    expected_substr = '
      <outer>
        <inner>value</inner>
      </outer>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_array_config
    config = ArrayConfig.new("name").add(0, "value0_1").add(0, "value0_2").
      add(1, "value1_1")
    actual = config.to_xml(" ")
    expected_substr = '<name>
      <item>value0_1value0_2</item>
      <item>value1_1</item>
    </name>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_map_config
    config = ConfigOverride.new("myconfig").add(MapConfig.new("mymap").add("key_a", "val_0").add("key_b", "val_1"))
    actual = config.to_xml(" ")

    expected_substr = '<config name="myconfig">
      <mymap>
        <item key="key_a">val_0</item>
        <item key="key_b">val_1</item>
      </mymap>
    </config>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_model_config_path
    config = ConfigOverride.new("myconfig").add(ModelConfig.new("mymodel", "myid", path: "mypath"))
    actual = config.to_xml(" ")

    expected_substr = '<config name="myconfig">
      <mymodel model-id="myid" path="mypath" />
    </config>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_model_config_url
    config = ConfigOverride.new("myconfig").add(ModelConfig.new("mymodel", "myid", url: "myurl"))
    actual = config.to_xml(" ")

    expected_substr = '<config name="myconfig">
      <mymodel model-id="myid" url="myurl" />
    </config>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_deploy_params
    app = SearchApp.new.sd("sd1").cluster(SearchCluster.new.sd("sd2")).
      rules_dir("dir3").
      components_dir("dir4").search_dir("dir5").
      rank_expression_file("file1").rank_expression_file("file2").num_hosts(3)

    sd_files = app.sd_files
    assert_equal(1, sd_files.size)
    assert_equal("sd1", sd_files[0])
    deploy_params = app.deploy_params
    assert_equal("dir3", deploy_params[:rules_dir])
    assert_equal("dir4", deploy_params[:components_dir])
    assert_equal("dir5", deploy_params[:search_dir])
    assert_equal(3, deploy_params[:num_hosts])
    rank_files = deploy_params[:rank_expression_files]
    assert_equal(2, rank_files.size)
    assert_equal("file1", rank_files[0])
    assert_equal("file2", rank_files[1])
    all_sd_files = deploy_params[:sd_files]
    assert_equal(2, all_sd_files.size)
    assert_equal("sd1", all_sd_files[0])
    assert_equal("sd2", all_sd_files[1])
  end

  def test_attribute_quoting
    actual = XmlHelper.new(' ').
      tag("name", :a1 => "'foo'", :a2 => '"bar"', :a3 => "\\ \\\" \' \n",
                  :a4 => "<>&").to_s
    expected_substr = '
       <name a1="&apos;foo&apos;" a2="&quot;bar&quot;"
             a3="\\ \\&quot; &apos; &#10;" a4="&lt;&gt;&amp;" />'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_streaming_with_bucketsplit
    actual = SearchApp.new.streaming.
             storage(StorageCluster.new("mystorage").
                     default_group.bucket_split_count(4)).
             storage(StorageCluster.new("not used").
                     default_group.bucket_split_count(8)).
             cluster(SearchCluster.new.sd("sd").storage_cluster("mystorage")).
             services_xml
    expected_substr = '
      <tuning>
        <bucket-splitting max-documents="4" />
      </tuning>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_default_with_doctype
    actual = create_default.
      cluster(SearchCluster.new("foo").sd("sd").
              doc_type("sd", "sd.foo == bar")).services_xml
    expected_substr = '
      <documents>
        <document-processing cluster="default" />
        <document mode="index" selection="sd.foo == bar" type="sd" />
      </documents>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_documents_selection
    actual = create_default.
      cluster(SearchCluster.new("foo").sd("sd").
              doc_type("sd", "sd.foo == bar")).services_xml
    expected_substr = '
      <document mode="index" selection="sd.foo == bar" type="sd" />'
    assert_substring_ignore_whitespace(actual, expected_substr)

    # Multiple selections
    actual = create_default.
      cluster(SearchCluster.new("foo").sd("sd").sd("sd2").
              doc_type("sd", "sd.foo == bar").
              doc_type("sd2", "sd2.baz == blarg")).services_xml
    expected_substr = '
      <document mode="index" selection="sd.foo == bar" type="sd" />
      <document mode="index" selection="sd2.baz == blarg" type="sd2" />'
    assert_substring_ignore_whitespace(actual, expected_substr)

    actual = create_default.
      cluster(SearchCluster.new("foo").sd("sd").sd("sd2").
              doc_type("sd", "sd.foo == bar").
              doc_type("sd2")).services_xml
    expected_substr = '
      <document mode="index" selection="sd.foo == bar" type="sd" />'
    assert_substring_ignore_whitespace(actual, expected_substr)

    actual = create_default.
      cluster(SearchCluster.new("foo").sd("sd", :selection => 'sd.foo == baz')).services_xml
    expected_substr = '
      <document mode="index" selection="sd.foo == baz" type="sd" />'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_that_global_document_type_can_be_specified
    actual = SearchApp.new.sd("test.sd", { :global => true }).services_xml
    expected_substr = '
      <documents>
        <document-processing cluster="default" />
        <document global="true" mode="index" type="test" />
      </documents>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_that_resource_limits_can_be_specified
    actual = SearchApp.new.
      cluster(SearchCluster.new("foo").
              resource_limits(ResourceLimits.new.disk(0.3).memory(0.4)).
              proton_resource_limits(ResourceLimits.new.disk(0.5).memory(0.6))).
      services_xml

    expected_tuning = '
      <content id="foo" version="1.0">
        <tuning>
          <resource-limits>
            <disk>0.3</disk>
            <memory>0.4</memory>
          </resource-limits>
        </tuning>'
    assert_substring_ignore_whitespace(actual, expected_tuning)

    expected_engine = '
        <engine>
          <proton>
            <searchable-copies>1</searchable-copies>
            <resource-limits>
              <disk>0.5</disk>
              <memory>0.6</memory>
            </resource-limits>
          </proton>
        </engine>'
    assert_substring_ignore_whitespace(actual, expected_engine)
  end

  def test_doc_api_and_feeder_options
    actual = SearchApp.new.enable_document_api(FeederOptions.new.timeout(40)).services_xml

    # Note: 'default' container needs to come first as there assumptions about
    # a search container being the first one in test framework and tests
    expected_substr =
    '<config name="vespa.config.content.fleetcontroller">
       <min_time_between_new_systemstates>100</min_time_between_new_systemstates>
       <min_distributor_up_ratio>0.1</min_distributor_up_ratio>
       <min_storage_up_ratio>0.1</min_storage_up_ratio>
       <storage_transition_time>0</storage_transition_time>
    </config>

    <container id="default" version="1.0">
      <search />
      <document-processing />
      <nodes>
        <node hostalias="node1" />
      </nodes>
    </container>

    <content id="search" version="1.0">
      <redundancy>1</redundancy>
      <config name="vespa.config.search.core.proton">
        <numthreadspersearch>4</numthreadspersearch>
        <initialize>
          <threads>16</threads>
        </initialize>
        <lidspacecompaction>
          <allowedlidbloat>100</allowedlidbloat>
          <allowedlidbloatfactor>0.01</allowedlidbloatfactor>
        </lidspacecompaction>
        <hwinfo>
          <disk>
            <shared>true</shared>
            <writespeed>150.0</writespeed>
          </disk>
        </hwinfo>
      </config>
      <documents>
        <document-processing cluster="default" />
      </documents>
      <group>
        <node hostalias="node1" distribution-key="0" />
      </group>
      <engine>
        <proton>
          <searchable-copies>1</searchable-copies>
        </proton>
      </engine>
    </content>

    <container id="doc-api" version="1.0">
      <document-api>
        <timeout>40</timeout>
      </document-api>
      <http>
        <server id="default" port="19020" />
      </http>
      <nodes>
        <node hostalias="node1" />
      </nodes>
    </container>'

    assert_substring_ignore_whitespace(actual, expected_substr)
  end

  def test_num_distributor_stripes_can_be_specified
    actual = SearchApp.new.storage(StorageCluster.new("search").num_distributor_stripes(1)).services_xml
    expected_substr = '
      <config name="vespa.config.content.core.stor-distributormanager">
        <num_distributor_stripes>1</num_distributor_stripes>'
    assert_substring_ignore_whitespace(actual, expected_substr)
  end

end
