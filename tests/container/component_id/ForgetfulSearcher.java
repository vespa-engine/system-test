// Copyright Vespa.ai. All rights reserved.
package com.yahoo.search.example;

import com.yahoo.search.*;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.component.ComponentId;

/**
 * A searcher adding a new hit, that takes ComponentId as a ctor arg, but forgets to call super(id).
 * This caused the searcher to get the classname as id, so if the searcher belonged to a namespace
 * (declared inside a chain), it could not be found when the search chains were built.
 */
public class ForgetfulSearcher extends Searcher {

  public ForgetfulSearcher(ComponentId id) {
    //super(id);  "Forget" to set componentId.
    System.out.println("SimpleSearcher constructed.");
  }

  @Override
  public Result search(Query query, Execution execution) {
    query.trace("Running SimpleSearcher", true, 3);
    Result result = execution.search(query); // Pass on to the next searcher to get results
    Hit hit = new Hit("test");
    hit.setField("message", "Hello world");
    result.hits().add(hit);
    query.trace("SimpleSearcher: result set: " + result.toString(), true, 3);
    return result;
  }

}
