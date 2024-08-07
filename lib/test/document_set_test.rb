# Copyright Vespa.ai. All rights reserved.
require 'test/unit'
require 'document'
require 'document_set'
require 'tempfile'

class DocumentSetTest < Test::Unit::TestCase

  def test_to_json
    docs = DocumentSet.new

    doc = Document.new('music', 'id:foo:music::1')
    doc.add_field('foo', 1)
    doc.add_field('bar', "some text")
    docs.add(doc)

    doc = Document.new('music', 'id:foo:music::2')
    doc.add_field('foo', 2)
    doc.add_field('bar', "some other text")
    docs.add(doc)

    json = docs.to_json
    expected = [
      {"put"=>"id:foo:music::1", "fields"=>{"bar"=>"some text", "foo"=>1}},
      {"put"=>"id:foo:music::2", "fields"=>{"bar"=>"some other text", "foo"=>2}}
    ]
    assert_equal(expected, JSON.parse(json))

    json = docs.to_json(:remove)
    expected = [
      {"remove"=>"id:foo:music::1"},
      {"remove"=>"id:foo:music::2"}
    ]
    assert_equal(expected, JSON.parse(json))
  end

  def test_write_to_json
    docs = DocumentSet.new

    doc = Document.new('music', 'id:foo:music::1')
    doc.add_field('foo', 1)
    doc.add_field('bar', "some text")
    docs.add(doc)


    file = Tempfile.new('foo')
    json = docs.write_json(file, :remove)
    expected = [
      {"remove"=>"id:foo:music::1"}
    ]
    assert_equal(expected, JSON.parse(File.read(file)))
  end

end
