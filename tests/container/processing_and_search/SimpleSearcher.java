// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.search.systemtest;

import com.yahoo.search.*;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;

public class SimpleSearcher extends Searcher {

  @Override
  public Result search(Query query, Execution execution) {
    Result result = execution.search(query); // Pass on to the next searcher to get results
    Hit hit = new Hit("test");
    hit.setField("message", "We can even have search chains and processing chains in one container!");
    result.hits().add(hit);
    return result;
  }

}
