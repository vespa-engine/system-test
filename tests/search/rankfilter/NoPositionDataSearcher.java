// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.rankfilter;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.query.Model;
import com.yahoo.search.query.QueryTree;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.prelude.query.Item;
import com.yahoo.prelude.query.WordItem;

public class NoPositionDataSearcher extends Searcher {

    @Override
    public Result search(Query query, Execution execution) {
        query.trace("Running NoPositionDataSearcher", true, 3);
        String prop = new String("noposdata");
        if (query.properties().get(prop) == null) {
            query.trace("Did not find '" + prop + "' property", true, 3);
            return execution.search(query);
        }
        Model model = query.getModel();
        QueryTree tree = model.getQueryTree();
        Item root = tree.getRoot();
        if (root instanceof WordItem) {
            WordItem word = (WordItem)root;
            WordItem newWord = (WordItem)word.clone();
            newWord.setPositionData(false);
            tree.setRoot(newWord);
            query.trace("Found and modified WordItem: " + newWord.toString(), true, 3);
        } else {
            query.trace("Root is not a WordItem: " + root.toString(), true, 3);
        }
        return execution.search(query);
    }

}
