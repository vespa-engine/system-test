// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespa.jaxtest;

import com.yahoo.container.jdisc.HttpResponse;
import com.yahoo.yolean.Exceptions;

import java.io.IOException;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.util.logging.Logger;

/**
* @author Einar M R Rosenvinge
*/
class JaxHttpResponse extends HttpResponse {
    private static final Logger log = Logger.getLogger(JaxHttpResponse.class.getName());

    private final String data;

    public JaxHttpResponse(String data) {
        this(200, data);
    }

    public JaxHttpResponse(int status, String data) {
        super(status);
        this.data = data;
    }

    public JaxHttpResponse(Throwable thr) {
        this(500, Exceptions.toMessageString(thr));
    }

    @Override
    public void render(OutputStream outputStream) throws IOException {
        Writer w = new OutputStreamWriter(outputStream, StandardCharsets.UTF_8);
        w.write(data);
        w.close();
        log.info("Response string: " + data);
    }
}
