// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import java.util.List;

import com.yahoo.document.DocumentUpdate;
import com.yahoo.document.datatypes.StringFieldValue;
import com.yahoo.docproc.SimpleDocumentProcessor;

public class PearDocProc extends SimpleDocumentProcessor {

    @Override
    public void process(DocumentUpdate docU) {
        docU.getFieldUpdate("pear").getValueUpdate(0).setValue(new StringFieldValue("Pear"));
    }

}
