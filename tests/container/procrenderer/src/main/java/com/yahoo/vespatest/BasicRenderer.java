// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import java.io.IOException;
import java.io.OutputStream;

import com.yahoo.processing.rendering.AsynchronousSectionedRenderer;
import com.yahoo.processing.Response;
import com.yahoo.processing.response.Data;
import com.yahoo.processing.response.DataList;
import com.yahoo.text.Utf8;

/**
 * Smoke test template for Processing API.
 *
 * @author <a href="mailto:steinar@yahoo-inc.com">Steinar Knutsen</a>
 */
public class BasicRenderer extends AsynchronousSectionedRenderer<Response> {

    @Override
    public void beginResponse(OutputStream stream)
            throws IOException {
        stream.write(Utf8.toBytes("Hello, world!"));
    }

    @Override
    public void beginList(DataList<?> list)
            throws IOException {
    }

    @Override
    public void data(Data data)
            throws IOException {
    }

    @Override
    public void endList(DataList<?> list)
            throws IOException {
    }

    @Override
    public void endResponse()
            throws IOException {
    }

    @Override
    public String getEncoding() {
        return "UTF-8";
    }

    @Override
    public String getMimeType() {
        return "text/plain";
    }

}
