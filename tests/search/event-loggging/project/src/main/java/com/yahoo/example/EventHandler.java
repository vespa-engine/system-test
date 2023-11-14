// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.example;

import com.yahoo.component.annotation.Inject;
import com.yahoo.container.jdisc.HttpRequest;
import com.yahoo.container.jdisc.HttpResponse;
import com.yahoo.container.jdisc.ThreadedHttpRequestHandler;
import com.yahoo.restapi.SlimeJsonResponse;
import com.yahoo.slime.Cursor;
import com.yahoo.slime.Slime;
import java.util.concurrent.Executor;

/**
 * @author musum
 */
public class EventHandler extends ThreadedHttpRequestHandler {

    private final EventStore eventStore;

    @Inject
    public EventHandler(Executor executor, EventStore eventStore) {
        super(executor);
        this.eventStore = eventStore;
    }

    @Override
    public HttpResponse handle(HttpRequest request) {
        if (request.getMethod() == com.yahoo.jdisc.http.HttpRequest.Method.GET) {
             return get();
        } else {
            Slime slime = new Slime();
            Cursor root = slime.setObject();
            root.setString("error", "Unknown method " + request.getMethod().name());
            return new SlimeJsonResponse(500, slime);
        }
    }

    private HttpResponse get() {
        Slime slime = new Slime();
        Cursor root = slime.setObject();

        root.setLong("count", eventStore.eventCount());
        root.setString("lastBlob", eventStore.last());
        return new SlimeJsonResponse(200, slime);
    }

}
