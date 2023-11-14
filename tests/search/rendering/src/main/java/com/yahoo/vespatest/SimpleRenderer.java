// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.search.Result;
import com.yahoo.search.rendering.Renderer;

import java.io.IOException;
import java.io.Writer;

import com.yahoo.vespatest.SimpleRendererConfig;

/**
 * @author tonyv
 */
public class SimpleRenderer extends Renderer {

    private final String text;

    public SimpleRenderer(SimpleRendererConfig config) {
        text = config.text();
    }

    @Override
    public void render(Writer writer, Result result) throws IOException {
        writer.write(text + " " + result.getHitCount());
    }

    @Override
    public String getEncoding() {
        return "utf-8";
    }

    @Override
    public String getMimeType() {
        return "text/plain";
    }

}
