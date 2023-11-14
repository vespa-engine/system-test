// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.prelude.systemtest;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.prelude.query.Highlight;
import java.util.Arrays;

public class HighlightSearcher extends Searcher {

    public Result search(Query query, Execution execution) {
        Highlight highlight = new Highlight();
        highlight.addHighlightTerm("title", "test");
        highlight.addHighlightTerm("title", "\u9001\u82B1\u9053\u6B49");
        highlight.addHighlightTerm("categories", "jazz");
        String[] phrase = { "kentucky", "fried", "chicken" };
        highlight.addHighlightPhrase("title", Arrays.asList(phrase));

        query.getPresentation().setHighlight(highlight);
        return execution.search(query);
    }
}

