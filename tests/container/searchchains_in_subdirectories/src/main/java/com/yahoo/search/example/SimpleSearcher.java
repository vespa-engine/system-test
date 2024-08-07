// Copyright Vespa.ai. All rights reserved.
package com.yahoo.search.example;

import com.yahoo.search.*;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.*;
import com.yahoo.yolean.chain.Before;
import com.yahoo.yolean.chain.Provides;

/**
 * A searcher adding a new hit.
 *
 * @author  Joe Developer
 */
@Before("S2")
@Provides("S")
public class SimpleSearcher extends Searcher {

  @Override
  public Result search(Query query, Execution execution) {
    query.trace("Running simpleSearcher", true, 3);
    Result result = execution.search(query); // Pass on to the next searcher to get results
    Hit hit = new Hit("test",2d);
    hit.setField("message", "Hello world");
    result.hits().add(hit);
    query.trace("SimpleSearcher: result set: " + result.toString(), true, 3);
    return result;
  }

}
