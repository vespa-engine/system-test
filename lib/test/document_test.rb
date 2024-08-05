# Copyright Vespa.ai. All rights reserved.
require 'test/unit'
require "rexml/document"
require 'document'

class DocumentTest < Test::Unit::TestCase

  @@json = <<EOS
{"put": "id:test:test::1", "fields":{"artist":"Yello","popularity":null,"title":"Pocket Universe [Bonus Track]","url":"http://music.yahoo.com/Yello/Pocket+Universe+%5BBonus+Track%5D","novalue":null,"price":9.99,"year":1999,"tracks":["Track 1","Track 2"],"map":{"foo":1,"bar":2},"weighted_set":{"baz":10,"quux":11},"struct":"#<struct Struct::Customer name=\\"John & Martha Smith\\", address=\\"1 High Street\\">","misc":"Some string, insert <text> here"}}
EOS

  def test_compare
    puts "in test_compare_foo"

    doc1 = Document.new('music', 'id:music:music::1')
    doc1.add_field('novalue', nil)
    doc1.add_field('year', 1999)
    doc1.add_field('tracks', ['Track 1', 'Track 2'])
    doc1.add_field('map', { 'foo' => 1, 'bar' => 2})
    doc1.add_field('weighted_set', {'baz' => 10, 'quux' => 11})

    doc2 = Document.new('music', 'id:music:music::1')
    doc2.add_field('weighted_set', {'baz' => 10, 'quux' => 11})
    doc2.add_field('novalue', nil)
    doc2.add_field('year', 1999)
    doc2.add_field('map', { 'foo' => 1, 'bar' => 2})
    doc2.add_field('tracks', ['Track 1', 'Track 2'])

    assert(doc1 == doc2)
  end

  def test_to_json
    document = Document.create_from_json(JSON.parse(@@json), 'test')
    add_fields(document)
    expected_json = <<EOS
{"fields":{"artist":"Yello","popularity":null,"title":"Pocket Universe [Bonus Track]","url":"http://music.yahoo.com/Yello/Pocket+Universe+%5BBonus+Track%5D","novalue":null,"price":9.99,"year":1999,"tracks":["Track 1","Track 2"],"map":{"foo":1,"bar":2},"weighted_set":{"baz":10,"quux":11},"struct":"#<struct Struct::Customer name=\\"John & Martha Smith\\", address=\\"1 High Street\\">","misc":"Some string, insert <text> here"}}
EOS
    assert_equal(expected_json, document.fields_to_json + "\n")

    # Remove
    document = Document.new('music', 'id:music:music::1')
    json = document.to_json(:remove)
    expected_json = <<EOS
{"remove":"id:music:music::1"}
EOS
    assert_equal(expected_json, document.to_json(:remove) + "\n")
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
