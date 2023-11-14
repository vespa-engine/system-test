// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.queryfeatures;

import com.yahoo.search.Result;
import com.yahoo.search.Query;
import com.yahoo.search.Searcher;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.prelude.query.*;

public class ReverseSearcher extends Searcher {

    @Override
    public Result search(Query query, Execution execution) {
        if (query.getModel().getQueryTree().getRoot() instanceof CompositeItem) {
            CompositeItem root = (CompositeItem) query.getModel().getQueryTree().getRoot();
            for (int i = 0; i < root.getItemCount(); ++i) {
                WordItem item = (WordItem) root.getItem(i);
                query.trace("[" + i + "]: '" + item.getWord() + "': termIndex(" + i + ")", true, 3);
            }
        }

        if (query.properties().get("reverse") == null) {
            return execution.search(query);
        }

        query.trace("reverse terms", true, 3);
        if (query.getModel().getQueryTree().getRoot() instanceof CompositeItem) {
            CompositeItem root = (CompositeItem) query.getModel().getQueryTree().getRoot();
            CompositeItem newRoot = (CompositeItem) root.clone();
            for (int i = 0; i < root.getItemCount(); ++i) {
                WordItem item = (WordItem) root.getItem(root.getItemCount() - 1 - i);
                WordItem newItem = (WordItem) item.clone();
                query.trace("set '" + item.getWord() + "' as item " + i + " in new root", true, 3);
                newRoot.setItem(i, newItem);
            }
            query.getModel().getQueryTree().setRoot(newRoot);
        }
        return execution.search(query);
    }

}
