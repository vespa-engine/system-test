# Copyright Vespa.ai. All rights reserved.
require 'search_test'
require 'json'

class FieldPath < SearchTest

  def setup
    set_owner("johsol")
    set_description("Test fieldpath update with searching")

    deploy_app(SearchApp.new.sd(selfdir + "test_field_path.sd"))
    start
    feedfile(selfdir + "feed_complex.json")
  end

  def test_update
    check_fullquery('yql=select * from sources * where true', 'update-before')

    feedfile(selfdir + "update.json")

    check_fullquery('yql=select * from sources * where true', 'update-after')
  end

  def test_update_using_match
    check_fullquery('yql=select * from sources * where true', 'update-before')

    feedfile(selfdir + "update_using_match.json")

    check_fullquery('yql=select * from sources * where true', 'update-after')
  end

  def check_fullquery(query, localfile)
    puts "check #{query} with #{localfile}"
    file = selfdir + 'answers/' + localfile + '.json'
    assert_result(query, file)
  end


end
