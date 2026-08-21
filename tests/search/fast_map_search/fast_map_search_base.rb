# Copyright Vespa.ai. All rights reserved.
module FastMapSearchBase

  # 'map: fast-search' makes the config model add a synthetic attribute holding one
  # string per map entry, on the form key + DEL + value, so that a key-value pair
  # can be matched with a single lexical lookup.
  KEY_VALUE_FIELD = "_my_map_keyvalue"
  KEY_VALUE_SEPARATOR = "%7F"

  def setup
    set_description("Tests fast map search feature")
    set_owner("johsol")
  end

  def test_fast_map_search_basic
    deploy_app(SearchApp.new.sd(write_sd("map: fast-search")))
    start
    feed_and_wait_for_docs("fast_map_search", 1, :file => selfdir+"feed.json")

    # The whole key-value pair matches, parts of it do not.
    assert_key_value_hitcount("foo", "bar", 1)
    assert_key_value_hitcount("foo", "baz", 0)
    assert_term_hitcount("foo", 0)
    assert_term_hitcount("bar", 0)

    # The synthetic attribute is internal, and is not part of the summary.
    assert_result("query=sddocname:fast_map_search", selfdir + "result.json")
  end

  def assert_key_value_hitcount(key, value, expected_hitcount)
    assert_term_hitcount("#{key}#{KEY_VALUE_SEPARATOR}#{value}", expected_hitcount)
  end

  def assert_term_hitcount(term, expected_hitcount)
    assert_hitcount("yql=select+*+from+fast_map_search+where+#{KEY_VALUE_FIELD}+contains+%22#{term}%22",
                    expected_hitcount)
  end

  def write_sd(field_body)
    sd_file = "#{dirs.tmpdir}fast_map_search.sd"
    File.write(sd_file, <<~SD)
      schema fast_map_search {
        document fast_map_search {
          field my_map type map<string, string> {
            indexing: summary
            #{field_body}
          }
        }
      }
    SD
    sd_file
  end

  # Indexed and streaming config can discover these tests.
  def self.included(base)
    public_instance_methods.grep(/^test_/).each do |name|
      base.send(:define_method, name, instance_method(name))
    end
  end

end
