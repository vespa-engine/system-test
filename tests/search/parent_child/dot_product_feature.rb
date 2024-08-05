# Copyright Vespa.ai. All rights reserved.
require 'search/parent_child/parent_child_test_base'

class ParentChildDotProductFeatureTest < ParentChildTestBase

  def setup
    set_owner('vekterli')
    @test_dir = "dot_product_feature"
  end

  def deploy_and_start
    app = SearchApp.new.sd(get_sub_test_path("parent.sd"), { :global => true }).
                        sd(get_test_path("child.sd"))
    app.sd(get_sub_test_path("grandparent.sd"), { :global => true }) if is_grandparent_test
    deploy_app(app)
    start
  end

  def feed_baseline
    feed_and_wait_for_docs('parent', 2, :file => get_sub_test_path("parent-docs.json"))
    feed_and_wait_for_docs('child', 3, :file => get_test_path("child-docs.json"))
  end

  # TODO re-evaluate need for multiple inputs for expected and vectors; currently just use 1 per in tests.
  def check_dot_product(doc, expected, vectors)
    vectors_as_params = vectors.map{|v| "&rankproperty.dotProduct.#{v}"}.reduce(:+)
    result = search("query=sddocname:child#{vectors_as_params}&presentation.format=json")
    expected_remapped = expected.map{|k, v| ["dotProduct(#{k})", v]}.to_h
    wanted_hit = result.hit.find{|h| h.field['documentid'] == doc}

    assert_not_nil(wanted_hit, "Document #{doc} not found as part of result set")
    assert_features(expected_remapped, wanted_hit.field["summaryfeatures"], 1e-4)
  end

  def teardown
    stop
  end

  def test_dot_product_feature_can_be_used_with_imported_attributes
    set_description("Test that dot product feature can be used with imported attributes")
    run_dot_product_feature_can_be_used_with_imported_attributes("parent")
  end

  def test_dot_product_feature_can_be_used_with_imported_grandparent_attributes
    set_description("Test that dot product feature can be used with imported grandparent attributes")
    run_dot_product_feature_can_be_used_with_imported_attributes("grandparent")
  end

  def run_dot_product_feature_can_be_used_with_imported_attributes(sub_test_dir)
    @sub_test_dir = sub_test_dir
    deploy_and_start
    feed_baseline

    check_dense_integer_arrays
    check_sparse_integer_arrays
    check_dense_long_arrays
    check_sparse_long_arrays
    check_dense_float_arrays
    check_sparse_float_arrays
    check_dense_double_arrays
    check_sparse_double_arrays

    check_fast_search_integer_arrays
    check_fast_search_long_arrays
    check_fast_search_float_arrays
    check_fast_search_double_arrays

    check_integer_weighted_set
    check_long_weighted_set
    check_string_weighted_set
  end

  def d1
    'id:test:child::one'
  end

  def d2
    'id:test:child::two'
  end

  def bad_ref
    'id:test:child::badref'
  end

  def check_dense_integer_arrays
    # Test minimum of query vector vs document vector lengths
    check_dot_product(d1, {'my_arr_i,varr_i' => 0}, ['varr_i=[]'])
    check_dot_product(d1, {'my_arr_i,varr_i' => 2*10}, ['varr_i=[2]'])
    check_dot_product(d1, {'my_arr_i,varr_i' => 3*10 + 4*20}, ['varr_i=[3 4]'])
    check_dot_product(d1, {'my_arr_i,varr_i' => 3*10 + 4*20 + 5*30 + 6*40}, ['varr_i=[3 4 5 6]'])
    check_dot_product(d1, {'my_arr_i,varr_i' => 3*10 + 4*20 + 5*30 + 6*40}, ['varr_i=[3 4 5 6 7 8 9]'])

    check_dot_product(d2, {'my_arr_i,varr_i' => 2*110 + 3*120 + 4*130}, ['varr_i=[2 3 4]'])

    check_dot_product(bad_ref, {'my_arr_i,varr_i' => 0}, ['varr_i=[2 3 4]'])
  end

  def check_sparse_integer_arrays
    check_dot_product(d1, {'my_arr_i,varr_i' => 9*20 + 29*30}, ['varr_i={1:9,2:29}'])
    check_dot_product(d2, {'my_arr_i,varr_i' => 9*110 + 29*140}, ['varr_i={0:9,3:29,9999:50}'])

    check_dot_product(bad_ref, {'my_arr_i,varr_i' => 0}, ['varr_i={0:9,3:29,9999:50}'])
  end

  def check_dense_long_arrays
    check_dot_product(d1, {'my_arr_l,varr_l' => 3*11 + 5*21 + 7*31 + 13*41}, ['varr_l=[3 5 7 13]'])
    check_dot_product(d2, {'my_arr_l,varr_l' => 3*111 + 5*121 + 7*131 + 13*141}, ['varr_l=[3 5 7 13]'])
  end

  def check_sparse_long_arrays
    check_dot_product(d1, {'my_arr_l,varr_l' => 9*21 + 29*31}, ['varr_l={1:9,2:29}'])
    check_dot_product(d2, {'my_arr_l,varr_l' => 9*111 + 29*141}, ['varr_l={0:9,3:29,9999:50}'])
  end

  def check_dense_float_arrays
    check_dot_product(d1, {'my_arr_f,varr_f' => 3.1*12.1 + 5.2*22.2}, ['varr_f=[3.1 5.2 7.3]'])
    check_dot_product(d2, {'my_arr_f,varr_f' => 3.2*112.1 + 5.3*122.2}, ['varr_f=[3.2 5.3]'])
  end

  def check_sparse_float_arrays
    check_dot_product(d1, {'my_arr_f,varr_f' => 9.5*12.1 + 2.75*22.2}, ['varr_f={0:9.5,1:2.75}'])
    check_dot_product(d2, {'my_arr_f,varr_f' => 9.5*112.1 + 2.75*122.2}, ['varr_f={0:9.5,1:2.75,9999:50.5}'])
  end

  def check_dense_double_arrays
    check_dot_product(d1, {'my_arr_d,varr_d' => 3.1*13.1 + 5.2*23.2 + 7.3*33.3}, ['varr_d=[3.1 5.2 7.3]'])
    check_dot_product(d2, {'my_arr_d,varr_d' => 3.1*113.1 + 5.2*123.2 + 7.3*133.3}, ['varr_d=[3.1 5.2 7.3]'])
  end

  def check_sparse_double_arrays
    check_dot_product(d1, {'my_arr_d,varr_d' => 9.5*13.1 + 2.75*33.3}, ['varr_d={0:9.5,2:2.75}'])
    check_dot_product(d2, {'my_arr_d,varr_d' => 9.5*113.1 + 2.75*133.3}, ['varr_d={0:9.5,2:2.75,9999:50.5}'])
  end

  def check_integer_weighted_set
    check_dot_product(d1, {'my_ws_i,vws_i' => 9*13 + 29*21}, ['vws_i={10:9,20:29,9999:50}'])
    check_dot_product(d2, {'my_ws_i,vws_i' => 9*31 + 29*34}, ['vws_i={10:9,20:29,9999:50}'])

    check_dot_product(bad_ref, {'my_ws_i,vws_i' => 0}, ['vws_i={10:9,20:29,9999:50}'])
  end

  def check_long_weighted_set
    check_dot_product(d1, {'my_ws_l,vws_l' => 9*23 + 29*27}, ['vws_l={11:9,21:29,9999:50}'])
    check_dot_product(d2, {'my_ws_l,vws_l' => 9*37 + 29*41}, ['vws_l={11:9,21:29,9999:50}'])
  end

  def check_string_weighted_set
    check_dot_product(d1, {'my_ws_s,vws_s' => 11*5 + 13*7 + 17*9}, ['vws_s={foo:11,bar:13,baz:17,blop:999}'])
    check_dot_product(d2, {'my_ws_s,vws_s' => 11*2 + 13*3 + 17*5}, ['vws_s={foo:11,bar:13,baz:17,blop:999}'])
  end

  def check_fast_search_integer_arrays
    # We only bother to check dense arrays for these; shouldn't trigger any different backend paths.
    check_dot_product(d1, {'my_arr_fi,varr_fi' => 2*10 + 3*20 + 4*30 + 5*40}, ['varr_fi=[2 3 4 5]'])
    check_dot_product(d2, {'my_arr_fi,varr_fi' => 2*110 + 3*120 + 4*130 + 5*140}, ['varr_fi=[2 3 4 5]'])

    check_dot_product(bad_ref, {'my_arr_fi,varr_fi' => 0}, ['varr_fi=[2 3 4 5]'])
  end

  def check_fast_search_long_arrays
    check_dot_product(d1, {'my_arr_fl,varr_fl' => 2*11 + 3*21 + 4*31}, ['varr_fl=[2 3 4 5]'])
    check_dot_product(d2, {'my_arr_fl,varr_fl' => 2*111 + 3*121 + 4*131 + 5*141}, ['varr_fl=[2 3 4 5]'])
  end

  def check_fast_search_float_arrays
    check_dot_product(d1, {'my_arr_ff,varr_ff' => 2.2*12.1 + 3.3*22.2 + 4.4*32.3 + 5.5*42.4}, ['varr_ff=[2.2 3.3 4.4 5.5]'])
    check_dot_product(d2, {'my_arr_ff,varr_ff' => 3.3*112.1 + 4.4*122.2}, ['varr_ff=[3.3 4.4]'])
  end

  def check_fast_search_double_arrays
    check_dot_product(d1, {'my_arr_fd,varr_fd' => 2.2*13.1 + 4.4*23.2}, ['varr_fd=[2.2 4.4]'])
    check_dot_product(d2, {'my_arr_fd,varr_fd' => 3.3*113.1 + 4.4*123.2 + 5.5*133.3}, ['varr_fd=[3.3 4.4 5.5]'])
  end

end

