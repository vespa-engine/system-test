// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.result.Hit;
import com.yahoo.search.result.StructuredData;
import com.yahoo.search.result.FeatureData;

import com.yahoo.search.searchchain.Execution;
import com.yahoo.yolean.chain.Before;
import com.yahoo.yolean.chain.After;

import com.yahoo.data.access.*;

@Before("blendedResult")
@After("transformedQuery")
public class DebugDataSearcher extends Searcher {

    public Result search(Query query, Execution execution) {
	Result r = execution.search(query);
	execution.fill(r);
	for (Hit hit : r.hits().asList()) {
	    if (hit.isMeta()) continue;
	    StringBuilder pasteBuf = new StringBuilder();
	    pasteBuf.append("\n");
	    String fn = "meta_tags";
	    Object o = hit.getField(fn);
	    if (o instanceof StructuredData) {
		StructuredData field = (StructuredData)o;
		Inspector obj = field.inspect();
		pasteBuf.append("field ").append(fn).append(" (StructuredData): ");
		pasteBuf.append(field.toJson());
		pasteBuf.append("\n");
	    } else if (o == null) {
		pasteBuf.append("field ").append(fn).append(": ");
		pasteBuf.append("(null)");
		pasteBuf.append("\n");
	    } else {
		pasteBuf.append("field ").append(fn).append(": ");
		pasteBuf.append(o.toString());
		pasteBuf.append(" class=").append(o.getClass().toString());
		pasteBuf.append("\n");
	    }
	    hit.setField("bamf", pasteBuf.toString());
	}
	return r;
    }

}
