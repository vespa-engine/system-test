# Copyright Vespa.ai. All rights reserved.
require 'vds_test'
require 'json'

class FieldPath < VdsTest

  def setup
    set_owner("vekterli")

    deploy_app(default_app("banana"))
    start
    feedfile(selfdir + "feed_complex.json")
  end

  def test_assign
    feedfile(selfdir + "assign_update.json")
    output = JSON.parse(visit)

    fields = output[0]['fields']
    assert_equal('cafe latte', fields['colour'])
    assert_equal('raspeballer', fields['stringmap']['foo1 hello'])
    assert_equal('bar1', fields['stringmap']['foo1 "hel}lo"}'])
    assert_equal('new and shiny', fields['stringmap']['foo4'])
    assert_equal('should not happen', fields['structmap']['4']['mymap']['foo'])
  end

  def test_add
    feedfile(selfdir + "add_update.json")
    output = JSON.parse(visit)

    assert_equal([{"title"=>"mytitle", "bytearr"=>[7, 9]},
                  {"title"=>"mytitle2", "bytearr"=>[7, 25]},
                  {"bytearr"=>[30, 55], "mymap"=>{"duke"=>"nukem"}},
                  {"bytearr"=>[12, 56], "mymap"=>{"emacs"=>"is fun and cool!!"}}],
                 output[0]['fields']['structarr'])
  end

  def test_remove
    feedfile(selfdir + "remove_update.json")
    output = JSON.parse(visit)
    puts "structarr: #{output[0]['fields']['structarr']}"

    assert_equal({"foo3"=>"bar3", "foo1 \"hel}lo\"}"=>"bar1"},
                 output[0]['fields']['stringmap'])

# TODO: Fix, syntax for removing from an array is not dcoumented, could be wrong syntax in remove_update.json
#    assert_equal([{"title"=>"mytitle2", "bytearr"=>[7, 25]}],
#                 output[0]['fields']['structarr'])
  end

  def visit
    output = vespa.storage["storage"].storage["0"].execute("vespa-visit")
  end


end
