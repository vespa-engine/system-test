// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import java.util.List;
import com.yahoo.docproc.*;
import com.yahoo.document.*;
import com.yahoo.document.datatypes.*;

public class OuterDocProcessor extends DocumentProcessor {

    public OuterDocProcessor() {
        System.err.println("OuterDocProcessor LOADED!");
    }

    @Override
    public Progress process(Processing processing) {
        for (DocumentOperation op : processing.getDocumentOperations()) {
            System.err.println(getId() + " GOT OUTERDOC: " + op.getId());
            Array docArray = (Array) ((DocumentPut)op).getDocument().getFieldValue("innerdocuments");
            for (int i = 0; i < docArray.size(); i++) {
                System.err.println(getId() + " GOT INNERDOC: " + docArray.get(i));
	    }
        }
        processing.getDocumentOperations().clear();
        return Progress.DONE;
    }

}
