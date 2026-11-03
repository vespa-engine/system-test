# Copyright Vespa.ai. All rights reserved.

require 'indexed_only_search_test'

class SchemaSkillTest < IndexedOnlySearchTest

  def setup
    set_owner("bratseth")
    set_description("Tests that the schema skill at /skills/v1")
  end

  def test_schema_skill
    container = Container.new('default')
                  .search(Searching.new)
                  .component("    <skills>\n      <schemas/>\n    </skills>\n")
    deploy_app(SearchApp.new.sd(selfdir + 'music.sd').sd(selfdir + 'book.sd').container(container))
    start
    wait_for_skills

    assert_contains('/skills/v1', '/skills/v1/schemas')
    assert_contains('/skills/v1/schemas',
                    'music', 'Music albums with their artists',
                    'book', 'Books with their authors')
    assert_contains('/skills/v1/schemas/music',
                    'Music albums with their artists',
                    'album', 'The title of the album',
                    'artist', 'The name of the artist who made the album',
                    'by_album', 'Ranks albums by how well the query matches the album title')
    assert_contains('/skills/v1/schemas/book',
                    'Books with their authors',
                    'title', 'The title of the book',
                    'year', 'The year the book was first published',
                    'newest', 'Ranks the most recently published books first')
  end

  # Waits until the container serves the skills, as it may not yet when start returns
  def wait_for_skills(timeout = 120)
    deadline = Time.now + timeout
    loop do
      begin
        return if get('/skills/v1').code == '200'
      rescue StandardError => e
        puts "Waiting for /skills/v1: #{e}"
      end
      flunk "/skills/v1 did not respond with 200 within #{timeout} seconds" if Time.now > deadline
      sleep 1
    end
  end

  def get(path)
    vespa.container.values.first.http_get('localhost', 0, path)
  end

  def assert_contains(path, *texts)
    response = get(path)
    assert_equal('200', response.code, "Response code from #{path}")
    body = response.body.force_encoding('UTF-8')
    puts "#{path}:\n#{body}"
    texts.each { |text| assert(body.include?(text), "Expected '#{text}' at #{path}") }
  end

end
