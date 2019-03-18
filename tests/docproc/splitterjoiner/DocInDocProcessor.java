// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import java.util.List;
import com.yahoo.docproc.*;
import com.yahoo.document.*;

public class DocInDocProcessor extends DocumentProcessor {

    public DocInDocProcessor() {
        System.err.println("DocInDocProcessor LOADED!");
    }

    @Override
    public Progress process(Processing processing) {
        for (DocumentOperation op : processing.getDocumentOperations()) {
            System.err.println(getId() + " GOT DOCINDOC: " + op.getId());
        }
        return Progress.DONE;
    }

}
