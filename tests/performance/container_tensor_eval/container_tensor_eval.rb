# Copyright Vespa.ai. All rights reserved.

require 'performance_test'
require 'app_generator/container_app'
require 'http_client'
require 'performance/fbench'
require 'pp'

class ContainerTensorEval < PerformanceTest
  CLIENTS = 64
  RUNTIME = 120
  
  def setup
    super
    set_owner('glebashnik')
    add_bundle_dir(selfdir + 'tensor-eval', 'tensor-eval', 
                   {:mavenargs => '-Dmaven.test.skip=true'}) 
  end

  def create_app
    handler = Handler.new('com.yahoo.vespatest.TensorEvalHandler')
                     .binding('http://*/TensorEval').bundle('tensor-eval')
    
    container = Container.new.handler(handler).jvmoptions(
      '-Xms8g -Xmx8g')
    
    app = ContainerApp.new.container(container)
    output = deploy_app(app)    
    start
    wait_for_application(@vespa.container.values.first, output)
  end

  def test_container_tensor_eval
    set_description('Test container tensor operations performance')
    create_app
    
    container = @vespa.container.values.first
    query_file_name = 'tensor_eval_queries.txt'
    container.copy(selfdir + query_file_name, dirs.tmpdir)
    @queryfile = dirs.tmpdir + query_file_name
    
    profiler_start
    run_fbench(container, CLIENTS, RUNTIME, [])
    profiler_report()
  end
end
