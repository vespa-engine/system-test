# Copyright Vespa.ai. All rights reserved.

require 'search/bucketreadiness/bucketreadiness_base'

class BucketReadinessWhileDownAndUp < BucketReadinessBase

  def test_readiness_while_nodes_down_and_up
    set_description("Basic test for bucket readiness with 2 ready copies of each bucket and nodes going down and up")
    deploy_app(create_app("regular/test.sd"))
    start
    run_readiness_while_nodes_down_and_up_test
  end

  def test_readiness_while_nodes_down_and_up_fast_access
    set_description("Basic test for bucket readiness with 2 ready copies of each bucket and nodes going down and up with fast-access attribute")
    deploy_app(create_app("fast_access/test.sd"))
    start
    run_readiness_while_nodes_down_and_up_test
  end


end
