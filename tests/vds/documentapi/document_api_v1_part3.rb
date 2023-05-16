# Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require 'uri'
require 'vds/documentapi/document_api_v1_base'

class DocumentApiVdsPart3 < DocumentApiV1Base

  def test_put_with_condition
    assert_not_found(2, 9)
    assert_fails_with_precondition_violation {
      feed_single(2, 9, 'title', 'true')
    }
    assert_not_found(2, 9)
    assert_title(1, 8, 'title');
    assert_fails_with_precondition_violation {
      feed_single(1, 8, 'new_title', 'music.title=="wrong"')
    }
    assert_title(1, 8, 'title');
    feed_single(1, 8, 'new_title', 'music.title=="title"')
    assert_title(1, 8, 'new_title');
  end

  def test_put_with_condition_and_create
    assert_not_found(2, 9)
    feed_single(2, 9, 'title','music.title=="wrong"', true)
    assert_title(2, 9, 'title')
    assert_fails_with_precondition_violation {
      feed_single(2, 9, 'new_title','music.title=="wrong"', true)
    }
    assert_title(2, 9, 'title')
    feed_single(2, 9, 'new_title','music.title=="title"', true)
    assert_title(2, 9, 'new_title')
  end

  def test_delete_with_condition
    assert_title(1, 8, 'title');
    assert_fails_with_precondition_violation {
      api_http_delete("/document/v1/storage_test/music/number/1/8?condition=#{CGI.escape('music.title=="wrong"')}")
    }
    assert_title(1, 8, 'title');
    api_http_delete("/document/v1/storage_test/music/number/1/8?condition=#{CGI.escape('music.title=="title"')}")
    assert_not_found(1, 8);
  end

  def test_delete_non_existent_with_condition
    # conditional delete of non existent document in a non existent bucket
    api_http_delete("/document/v1/storage_test/music/number/3/5?condition=#{CGI.escape('true')}")

    # conditional delete of non existent document in existing bucket
    assert_fails_with_precondition_violation {
      api_http_delete("/document/v1/storage_test/music/number/1/15?condition=#{CGI.escape('true')}")
    }
  end

end
