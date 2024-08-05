// Copyright Vespa.ai. All rights reserved.
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
