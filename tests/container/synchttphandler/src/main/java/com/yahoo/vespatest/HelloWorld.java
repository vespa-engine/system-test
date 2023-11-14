// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import java.io.IOException;
import java.io.OutputStream;
import java.util.concurrent.Executor;

import com.yahoo.text.Utf8;

import com.yahoo.container.jdisc.HttpRequest;
import com.yahoo.container.jdisc.HttpResponse;
import com.yahoo.container.jdisc.ThreadedHttpRequestHandler;
import com.yahoo.container.logging.AccessLog;
import com.yahoo.jdisc.Response;

/**
 * Synchronous JDisc handler only emitting a silly string composed from
 * a query parameter.
 *
 * @author Steinar Knutsen
 */
public class HelloWorld extends ThreadedHttpRequestHandler {
    private final class HelloResponse extends HttpResponse {
        private final String name;

        public HelloResponse(int status, String name) {
            super(status);
            this.name = name;
        }

        @Override
        public void render(OutputStream stream) throws IOException {
            stream.write(Utf8.toBytes("Hello, " + name + "!"));
        }
    }

    public HelloWorld(Executor executor) {
        super(executor);
    }

    @Override
    public HttpResponse handle(HttpRequest request) {
        return new HelloResponse(Response.Status.OK,
            request.getProperty("name"));
    }

}
