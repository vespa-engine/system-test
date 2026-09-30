# Copyright Vespa.ai. All rights reserved.

# TODO: require 'indexed_only_search_test'
require 'indexed_streaming_search_test'
require 'document'
require 'document_set'
require 'reindexing'

# TODO: class ReindexingTest < IndexedOnlySearchTest
class ReindexingTest < IndexedStreamingSearchTest

  include Reindexing

  DOCUMENT_COUNT = 1000
  MUSIC_CLUSTER_ID = 'music'
  MOVIE_CLUSTER_ID = 'movie'
  MUSIC_DOC_TYPE = 'music'
  MOVIE_DOC_TYPE = 'movie'

  def setup
    set_owner("hmusum")
  end

  def test_add_const_field
    set_description("test that adds a constant bool field to documents and verifies that the correct value is assigned during reindexing")
    testdir = selfdir + "add_const_field/"

    # First, we use the schema without the field const_bool
    system("cp #{testdir}item.0.sd #{dirs.tmpdir}item.sd")
    app = SearchApp.new.sd(dirs.tmpdir + "item.sd")
    deploy_app(app)

    start

    puts "Feeding single document"
    doc = Document.new("id:test:item::0}")
    vespa.document_api_v1.put(doc)

    puts "Adding field to schema"
    # Add field const_bool to schema (outside of document)
    # This field should trivially be true for every document
    system("cp #{testdir}item.1.sd #{dirs.tmpdir}item.sd")
    app = SearchApp.new.sd(dirs.tmpdir + "item.sd")
    deploy_output = redeploy(app)

    puts "Waiting for config to settle"
    wait_for_application(vespa.container.values.first,
                         deploy_output)
    wait_for_config_generation_proxy(get_generation(deploy_output))

    puts "Triggering reindexing"
    ready = trigger_reindexing(app)
    wait_for_reindexing(ready)
    assert_documents_reindexed_after(ready["search"]["item"], 1, document_type: "item")

    puts "Feeding another document"
    doc = Document.new("id:test:item::1}")
    vespa.document_api_v1.put(doc)

    # Make sure both documents have the field const_bool set to true
    assert_hitcount("query=const_bool:true", 2)
    assert_hitcount("query=const_bool:false", 0)
  end

  def test_reindexing_with_multiple_content_clusters
    app = SearchApp.new.monitoring('vespa', 60).
        cluster(SearchCluster.new(MUSIC_CLUSTER_ID).sd(selfdir + 'music.sd')).
        cluster(SearchCluster.new(MOVIE_CLUSTER_ID).sd(selfdir + 'movie.sd')).
        container(Container.new('combinedcontainer').
            search(Searching.new).
            docproc(DocumentProcessing.new).
            documentapi(ContainerDocumentApi.new))
    deploy_app(app)
    start
    container_node = @vespa.container["combinedcontainer/0"]

    puts "Feeding #{MUSIC_DOC_TYPE} documents"
    music_file = generate_feed_file(container_node, MUSIC_DOC_TYPE)
    feed_and_wait_for_docs(MUSIC_DOC_TYPE, DOCUMENT_COUNT, { :file => music_file, :feed_node => container_node, :localfile => true })

    puts "Feeding #{MOVIE_DOC_TYPE} documents"
    movie_file = generate_feed_file(container_node, MOVIE_DOC_TYPE)
    feed_and_wait_for_docs(MOVIE_DOC_TYPE, DOCUMENT_COUNT, { :file => movie_file, :feed_node => container_node, :localfile => true })

    puts "Triggering reindexing"
    ready = trigger_reindexing(app)
    wait_for_reindexing(ready)
    assert_documents_reindexed_after(ready[MUSIC_CLUSTER_ID][MUSIC_DOC_TYPE], DOCUMENT_COUNT, document_type: MUSIC_DOC_TYPE)
    assert_documents_reindexed_after(ready[MOVIE_CLUSTER_ID][MOVIE_DOC_TYPE], DOCUMENT_COUNT, document_type: MOVIE_DOC_TYPE)
  end

  def test_reindexing_with_binary_in_text_field
    app = SearchApp.new.monitoring('vespa', 60).
        cluster(SearchCluster.new(MUSIC_CLUSTER_ID).sd(selfdir + 'music.sd')).
        container(Container.new('default').
            search(Searching.new).
            docproc(DocumentProcessing.new).
            documentapi(ContainerDocumentApi.new).
            config(ConfigOverride.new('vespa.configdefinition.ilscripts').
                     add('maxReplacementCharactersRatio', '0.99').
                     add('maxReplacementCharacters', '999999999')))
    deploy_app(app)
    start
    container_node = @vespa.container['default/0']
    puts "Feeding #{MUSIC_DOC_TYPE} documents"
    music_file = generate_feed_file(container_node, MUSIC_DOC_TYPE)
    feed_and_wait_for_docs(MUSIC_DOC_TYPE, DOCUMENT_COUNT, { :file => music_file, :feed_node => container_node, :localfile => true })
    feed_bad_binary_file
    assert_hitcount("title:ulimit", 1)

    # redeploy with default config
    app = SearchApp.new.monitoring('vespa', 60).
        cluster(SearchCluster.new(MUSIC_CLUSTER_ID).sd(selfdir + 'music.sd')).
        container(Container.new('default').
            search(Searching.new).
            docproc(DocumentProcessing.new).
            documentapi(ContainerDocumentApi.new))
    deploy_app(app)
    feed_and_wait_for_docs(MUSIC_DOC_TYPE, DOCUMENT_COUNT + 1, { :file => music_file, :feed_node => container_node, :localfile => true })
    assert_hitcount("title:ulimit", 1)

    puts "Triggering reindexing"
    ready = trigger_reindexing(app)
    wait_for_reindexing(ready)
    assert_documents_reindexed_after(ready[MUSIC_CLUSTER_ID][MUSIC_DOC_TYPE], DOCUMENT_COUNT + 1, document_type: MUSIC_DOC_TYPE)
    assert_hitcount("title:ulimit", 0) unless is_streaming
    @ignorable_messages.append(/classified as binary data/)
  end

  private
  def generate_feed_file(container_node, document_type)
    feed_file = "#{dirs.tmpdir}/#{document_type}.json"
    puts "Writing #{document_type} feed to #{feed_file}"
    container_node.write_document_operations(:put,
                                             { :fields => { :title => 'my title' } },
                                             "id:test:#{document_type}::",
                                             DOCUMENT_COUNT,
                                             feed_file)
    feed_file
  end


  def feed_bad_binary_file
    doc = Document.new('id:ns:music::bin-sh-binary')
    doc.add_field('title', read_utf8_file_with_replacement('/bin/sh'))
    docs = DocumentSet.new()
    docs.add(doc)
    file = "#{dirs.tmpdir}/input-bad.json";
    docs.write_json(file)
    result = feed(:file => file)
    puts("fed up with bad data: #{result}")
  end

  def read_utf8_file_with_replacement(file_path)
    content = File.read(file_path, encoding: 'UTF-8', invalid: :replace, undef: :replace, replace: "\u{FFFD}")
    content = content.encode('UTF-8', 'UTF-8', invalid: :replace, undef: :replace, replace: "\u{FFFD}")
    # Replace control characters (0x00-0x1F and 0x7F-0x9F) except whitespace (tab, newline, carriage return)
    content.gsub(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]/, "\u{FFFD}")
  end

end
