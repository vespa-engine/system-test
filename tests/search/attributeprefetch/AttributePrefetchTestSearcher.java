// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest.attributeprefetch;

import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;

public class AttributePrefetchTestSearcher extends Searcher {

    public Result search(Query query, Execution execution) {
        Result result = execution.search(query);
        if (query.properties().get("notestsearcher") != null) {
            return result;
        }
        String error = null;
        Hit hit = null;
        boolean wasCached = false;

        if (result.getHitCount() == 1) {
            hit = result.hits().get(0);
            wasCached = hit.isCached();
        } else {
            error = "Hit count was " + result.getHitCount() + ", expected 1";
        }
        if (error == null && !wasCached) {
            String str = (String) hit.getField("stringfield");
            if (str != null) {
                error = "'stringfield' should not be set before filling in attributes";
            }
        }
        if (error == null && !wasCached) {
            String body = (String) hit.getField("body");
            if (body != null) {
                error = "'body' should not be set before filling in docsums";
            }
        }
        execution.fillAttributes(result);
        if (error == null && !wasCached) {
            String body = (String) hit.getField("body");
            if (body != null) {
                error = "'body' should not be set before filling in docsums";
            }
        }
        if (error == null) {
            String str = (String) hit.getField("stringfield");
            if (str == null) {
                error = "'stringfield' should be set after filling in attributes";
            } else if (!str.equals("stringvalue")) {
                error = "'stringfield' == " + str + " != \"stringvalue\"";
            }
        }
        execution.fill(result);
        if (error == null) {
            String body = (String) hit.getField("body");
            if (body == null) {
                error = "'body' should be set after filling in docsums";
            } else if (!body.equals("x")) {
                error = "'body' == " + body + " != \"x\"";
            }
        }
        Hit fb = new Hit("feedback");
        if (error == null) {
            fb.setField("feedback", "TEST SEARCHER: OK");
        } else {
            fb.setField("feedback", "TEST SEARCHER: ERROR: " + error);
        }
        result.hits().add(fb);
        return result;
    }

}
