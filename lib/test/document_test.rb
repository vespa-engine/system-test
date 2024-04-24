# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'test/unit'
require "rexml/document"
require 'document'

class DocumentTest < Test::Unit::TestCase
  @@xml1 = "<document documenttype='music' documentid='id:music:music::http://music.yahoo.com/Yello/Pocket+Universe+%5BBonus+Track%5D'>
  <artist>Yello</artist>
  <popularity/>
  <title>Pocket Universe [Bonus Track]</title>
  <url>http://music.yahoo.com/Yello/Pocket+Universe+%5BBonus+Track%5D</url>
</document>"

  def test_from_xml
    document = Document.create_from_xml(REXML::Document.new(@@xml1).root)
    assert_equal('music', document.documenttype)
    assert_equal('id:music:music::http://music.yahoo.com/Yello/Pocket+Universe+%5BBonus+Track%5D', document.documentid)
    fields = document.fields
    assert_equal('Yello', fields['artist'])
    assert_equal(nil, fields['popularity'])
  end

  def test_add_field
    document = Document.create_from_xml(REXML::Document.new(@@xml1).root)
    add_fields(document)
    fields = document.fields
    assert_equal('Pocket Universe [Bonus Track]', fields['title'])
    assert_equal(nil, fields['novalue'])
    assert_equal(9.99, fields['price'])
    assert_equal(1999, fields['year'])
    tracks = fields['tracks']
    assert_equal(2, tracks.size)
    assert_equal('Track 1', tracks[0])
    assert_equal('Track 2', tracks[1])
    map = fields['map']
    assert_equal(1, map['foo'])
    assert_equal(2, map['bar'])
    ws = fields['weighted_set']
    assert_equal('baz', ws.keys[0])
    assert_equal(10, ws['baz'])
    assert_equal('quux', ws.keys[1])
    assert_equal(11, ws['quux'])
    struct = fields['struct']
    assert_equal('John & Martha Smith', struct[:name])
    assert_equal('1 High Street', struct[:address])
    assert_equal('Some string, insert <text> here', fields['misc'])
  end

  def test_to_json
    document = Document.create_from_xml(REXML::Document.new(@@xml1).root)
    add_fields(document)
    expected_json = <<EOS
{"fields":{"artist":"Yello","popularity":null,"title":"Pocket Universe [Bonus Track]","url":"http://music.yahoo.com/Yello/Pocket+Universe+%5BBonus+Track%5D","novalue":null,"price":9.99,"year":1999,"tracks":["Track 1","Track 2"],"map":{"foo":1,"bar":2},"weighted_set":{"baz":10,"quux":11},"struct":"#<struct Struct::Customer name=\\"John & Martha Smith\\", address=\\"1 High Street\\">","misc":"Some string, insert <text> here"}}
EOS
    assert_equal(expected_json, document.fields_to_json + "\n")
  end

  def add_fields(document)
    document.add_field('novalue', nil)
    document.add_field('price', 9.99)
    document.add_field('year', 1999)
    document.add_field('tracks', ['Track 1', 'Track 2'])
    document.add_field('map', { 'foo' => 1, 'bar' => 2})
    document.add_field('weighted_set', {'baz' => 10, 'quux' => 11})
    Struct.new("Customer", :name, :address)
    document.add_field('struct', Struct::Customer.new("John & Martha Smith", "1 High Street"))
    document.add_field('misc', "Some string, insert <text> here")
  end

end
