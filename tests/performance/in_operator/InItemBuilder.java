// Copyright Vespa.ai. All rights reserved.
package ai.vespa.test;

import com.yahoo.component.chain.dependencies.After;
import com.yahoo.prelude.query.Item;
import com.yahoo.prelude.query.NumericInItem;
import com.yahoo.prelude.query.ToolBox;
import com.yahoo.processing.request.CompoundName;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.searchchain.Execution;

@After("ExternalYql")
public class InItemBuilder extends Searcher {
    @Override
    public Result search(Query query, Execution execution) {
        var lower = query.properties().getLong(new CompoundName("inbuilder.lower"));
        var upper = query.properties().getLong(new CompoundName("inbuilder.upper"));
        if (lower != null && upper != null) {
            ToolBox.visit(new InItemVisitor(lower, upper), query.getModel().getQueryTree().getRoot());
        }
        return execution.search(query);
    }

    private static class InItemVisitor extends ToolBox.QueryVisitor {

        private long lower;
        private long upper;

        public InItemVisitor(long lower, long upper) {
            this.lower = lower;
            this.upper = upper;
        }

        @Override
        public boolean visit(Item item) {
            if (item instanceof NumericInItem inItem) {
                for (long token = lower; token < upper; ++token) {
                    inItem.addToken(token);
                }
            }
            return true;
        }
    }
}
