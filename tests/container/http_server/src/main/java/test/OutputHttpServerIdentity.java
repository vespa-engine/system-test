// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package test;

import com.yahoo.component.provider.ComponentRegistry;
import com.yahoo.jdisc.http.server.jetty.JettyHttpServer;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.result.Hit;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.test.GenerationConfig;

/**
 * @author tonyv
 */
public class OutputHttpServerIdentity extends Searcher {

    private final JettyHttpServer httpServer;
    private final String generation;

    public OutputHttpServerIdentity(GenerationConfig config, //ensure that the instance of this is recreated
				    JettyHttpServer httpServer) {
        generation = config.generation();
        this.httpServer = httpServer;
    }

    @Override
    public Result search(Query query, Execution execution) {
        Result result = execution.search(query);
        result.hits().add(createIdentityHit(httpServer));
        return result;
    }

    private Hit createIdentityHit(JettyHttpServer server) {
        int id = System.identityHashCode(server);
        Hit hit = new Hit(generation + "--" + id);
        hit.setField("identityHashCode", "" + id);
        hit.setField("generation", generation);
        return hit;
    }

}
