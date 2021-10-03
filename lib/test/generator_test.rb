# Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'test/unit'
require 'generator'

class GeneratorTest < Test::Unit::TestCase

  def test_digest
    generator = Generator.new
    digest_command = generator.digest_command(command: 'echo "one two two three three three"', cutoff: 1)
    assert_equal(`#{digest_command}`,
                 "3 three\n2 two\n")
  end

  def test_feed
    generator = Generator.new
    doc = '{"id":"id:ns:type::$seq()", "text":"$words(2)", "chars": "$chars(2)", "ints": [$ints(2, 2)], "floats": $floats(), "filter": [$filter(10, 90)]}'
    feed_command = generator.feed_command(template: doc, count: 1, data: 'echo "1 one"')
    assert_equal(`#{feed_command}`,
                 "[\n{\"id\":\"id:ns:type::0\", \"text\":\"one one\", \"chars\": \"on\", \"ints\": [1, 1], \"floats\": 0.6007954689329611, \"filter\": [90]}\n]\n")
  end

  def test_query
    generator = Generator.new
    query = 'sddocname:test foo:$words() bar:$words()'
    query_command = generator.query_command(template: query, count: 2, parameters: {:a => 'b'})
    assert_equal(`#{query_command}`,
                 "/search/?query=sddocname%3Atest+foo%3Ared+bar%3Atwitter&a=b\n" +
                 "/search/?query=sddocname%3Atest+foo%3Athat+bar%3Aat&a=b\n")
  end

  def test_url
    generator = Generator.new
    path = '/document/v1/ns/type/docid/'
    url_command = generator.url_command(template: '$seq()', count: 1, path: path, parameters: {'%' => '%', :c => :d}, data: ':')
    assert_equal(`#{url_command}`,
                 "/document/v1/ns/type/docid/0?%25=%25&c=d\n")
  end

end

