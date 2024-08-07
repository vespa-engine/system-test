// Copyright Vespa.ai. All rights reserved.
package com.yahoo.search.example;

import com.yahoo.search.*;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;

/**
 * A searcher adding a new hit.
 *
 * @author  Joe Developer
 */
public class SimpleSearcher extends Searcher {

  @Override
  public Result search(Query query, Execution execution) {
    query.trace("Running simpleSearcher", true, 3);
    Result result = execution.search(query); // Pass on to the next searcher to get results
    Hit hit = new Hit("test");
    hit.setField("message", "Hello world");
    result.hits().add(hit);
    query.trace("SimpleSearcher: result set: " + result.toString(), true, 3);
    return result;
  }

}
