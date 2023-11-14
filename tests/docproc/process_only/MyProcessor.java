// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.docproc.SimpleDocumentProcessor;
import com.yahoo.document.DocumentPut;

public class MyProcessor extends SimpleDocumentProcessor {

    @Override
    public void process(DocumentPut put) {
        System.out.println("PROCESSED: " + put.getId());
    }

}
