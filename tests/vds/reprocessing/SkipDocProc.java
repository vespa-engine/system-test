// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import com.yahoo.document.*;
import com.yahoo.docproc.*;
import java.util.Iterator;

public class SkipDocProc extends DocumentProcessor {

    @Override
    public Progress process(Processing processing) {
        Iterator<DocumentOperation> it = processing.getDocumentOperations().iterator();
        while (it.hasNext()) {
            DocumentOperation document = it.next();
            it.remove();
            System.out.println("Processed " + document);
        }
        return Progress.DONE;
    }
}
