// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test;

import com.yahoo.search.Searcher;
import com.yahoo.search.Query;
import com.yahoo.search.Result;

import com.yahoo.search.searchchain.Execution;
import com.yahoo.yolean.chain.Before;
import com.yahoo.yolean.chain.After;

import com.yahoo.search.result.Hit;
import com.yahoo.search.result.StructuredData;
import com.yahoo.prelude.hitfield.JSONString;

import java.io.IOException;
import java.util.Iterator;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;

import static com.yahoo.search.result.ErrorMessage.*;

@After("rawQuery")
@Before("transformedQuery")
public class ShoppingUrlSearcher extends Searcher {

    private static final ObjectMapper jsonMapper = new ObjectMapper();

    public ShoppingUrlSearcher() {}

    public Result search(Query query, Execution execution) {
        Result r = execution.search(query);
        ensureFilled(r, null, execution);
        Iterator<Hit> iter = r.hits().deepIterator();
        while (iter.hasNext()) {
            Hit h = iter.next();
            try {
                Object v = h.getField("comprurl");
                String newval = extractString(v);
                if (newval != null) {
                    h.setField("ourl", newval);
                    h.removeField("comprurl");
                    // hit done OK
                }
            } catch (BadData e) {
                r.hits().addError(createErrorInPluginSearcher(e.getMessage(), e.getCause()));
            }
        }
        return r;
    }

    private ShoppingUrlCompression coder = new ShoppingUrlCompression();

    private String extractString(Object fieldValue) {
        if (fieldValue == null) {
            return null;
        }
        try {
            byte[] data = extractBytes(fieldValue);
            return coder.decompressString(data);
        } catch (java.util.zip.DataFormatException e) {
            throw new BadData("bad compressed data", e);
        }
    }

    private byte[] extractBytes(Object fieldValue) {
        if (fieldValue instanceof JSONString) {
            JSONString s = (JSONString)fieldValue;
            try {
                JsonNode p = jsonMapper.readTree(s.getContent());
                if (p instanceof ArrayNode) {
                    ArrayNode arr = (ArrayNode)p;
                    byte[] bytes = new byte[arr.size()];
                    for (int i = 0; i < arr.size(); i++) {
                        JsonNode val = arr.get(i);
                        bytes[i] = (byte) Integer.parseInt(val.asText());
                    }
                    return bytes;
                } else {
                    throw new BadData("expected JSON array, got: "+s.getContent(), null);
                }
            } catch (NumberFormatException e) {
                throw new BadData("bad number: "+e+" in JSON data: "+s.getContent(), e);
            } catch (IOException e) {
                throw new BadData("bad JSON: "+e+" data: "+s.getContent(), e);
            }
        } else if (fieldValue instanceof StructuredData) {
            StructuredData s = (StructuredData)fieldValue;
	    int length = s.inspect().entryCount();
	    byte[] bytes = new byte[length];
            for (int i = 0; i < length; i++) {
                bytes[i] = (byte) s.inspect().entry(i).asLong();
            }
            return bytes;
        } else {
            throw new BadData("expected bytes wrapped in JSON, got: "
                              +fieldValue.getClass()+" with value: "+fieldValue, null);
        }
    }

    static class BadData extends RuntimeException {
        BadData(String msg, Throwable cause) {
            super(msg, cause);
        }
    }
}
