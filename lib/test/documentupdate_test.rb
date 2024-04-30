require 'test/unit'
require 'documentupdate'

class DocumentUpdateTest < Test::Unit::TestCase

  def test_assign_update_to_json
    update = DocumentUpdate.new('music', 'id:foo:music::bar')
    update.addOperation('assign', 'title', 'cool titles for cool people')
    update.addOperation('assign', 'artist', 'groovy lads')

    json = update.fields_to_json
    expected = {
      'fields' => {
        'title'  => { 'assign' => 'cool titles for cool people' },
        'artist' => { 'assign' => 'groovy lads' }
      }
    }
    assert_equal(expected, JSON.parse(json))

    expected_with_update = {
      'update' => 'id:foo:music::bar',
      'fields' => {
        'title'  => { 'assign' => 'cool titles for cool people' },
        'artist' => { 'assign' => 'groovy lads' }
      }
    }
    assert_equal(expected_with_update, JSON.parse(update.to_json))
  end

  def test_simple_alter_update
    update = DocumentUpdate.new('doctype', 'id:foo:music::bar')
    update.addSimpleAlterOperation('increment', 'increment_field', 10)
    expected = {
      'update' => 'id:foo:music::bar',
      'fields' => {
        'increment_field' => { 'increment' => 10 }
      }
    }
    assert_equal(expected, JSON.parse(update.to_json))
  end

end
