# Copyright Vespa.ai. All rights reserved.
#
# To change this template, choose Tools | Templates
# and open the template in the editor.


require 'test/unit'
require 'rexml/document'
require 'hit'

class HitTest < Test::Unit::TestCase

  HITXML = "<hit relevancy=\"10\" source=\"sc0.num0\"> <field name=\"relevancy\">10</field><field name=\"title\">blues</field><field name=\"artist\">metallica</field></hit>"



  def test_init
    hit1 = Hit.new
    assert_equal(0, hit1.field.size)

    hit1.add_field("title", "test")
    hit1.add_field("cat", ["foo", "bar", "baz"])

    assert_equal(2, hit1.field.size)
    assert_equal("test", hit1.field["title"])

    assert_equal(3, hit1.field["cat"].size)
    hit2 = Hit.new(REXML::Document.new(HITXML).root)
    assert_equal(10, hit2.field['relevancy'].to_i)

    hit3 = Hit.new(HITXML)
    assert_equal(hit2, hit3)

  end

  def test_comparablefields
    hit = Hit.new(HITXML)
    assert_equal(["artist", "title"], hit.comparable_fields.keys.sort)
    hit.setcomparablefields(["title"])
    assert_equal(["title"], hit.comparable_fields.keys)
  end

end
