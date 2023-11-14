// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.exactmatch;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.query.Model;
import com.yahoo.search.query.QueryTree;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.prelude.query.Item;
import com.yahoo.prelude.query.WordItem;
import com.yahoo.prelude.query.ExactStringItem;
import com.yahoo.prelude.query.CompositeItem;
import java.lang.StringBuilder;

public class ExactMatchSearcher extends Searcher {
    public Result search(Query query, Execution execution) {
        query.trace("Running ExactMatchSearcher", true, 3);
        Model model = query.getModel();
        QueryTree tree = model.getQueryTree();
        Item root = tree.getRoot();
        query.trace("querytree = " + root, true, 3);
        if (root instanceof CompositeItem) {
            StringBuilder s = new StringBuilder();
            CompositeItem c = (CompositeItem) root;
            String indexName = "";
            for (int i=0; i < c.getItemCount(); i++) {
                Item item = c.getItem(i);
                if (item instanceof WordItem) {
                    indexName = ((WordItem) item).getIndexName();
                    if (s.length() != 0) {
                        s.append("@");
                    }
                    s.append(((WordItem)item).getWord());
                }
            }
            ExactStringItem exact = new ExactStringItem(s.toString());
            exact.setIndexName(indexName);
            tree.setRoot(exact);
            query.trace("new querytree = " + exact, true, 3);
        }
/*
        if (root instanceof WordItem) {
            WordItem word = (WordItem)root;
            WordItem newWord = (WordItem)word.clone();
            newWord.setPositionData(false);
            tree.setRoot(newWord);
            query.trace("Found and modified WordItem: " + newWord.toString(), true, 3);
        } else {
            query.trace("Root is not a WordItem: " + root.toString(), true, 3);
        }
*/
        return execution.search(query);
    }
}
