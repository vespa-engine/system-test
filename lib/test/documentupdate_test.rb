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
    assert_equal(expected_with_update, JSON.parse(update.to_update_json))
  end

end
