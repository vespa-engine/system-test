// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import com.yahoo.docproc.Processing;
import com.yahoo.document.Document;
import com.yahoo.document.DocumentOperation;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.datatypes.Array;
import com.yahoo.document.datatypes.StringFieldValue;

import com.yahoo.vespatest.order.OrderDocumentProcessor;

/**
 * @author Einar M R Rosenvinge
 */
public class SecondDocumentProcessor extends OrderDocumentProcessor {
    @Override
    public Progress process(Processing processing) {
        for (DocumentOperation op : processing.getDocumentOperations()) {
            if (op instanceof DocumentPut) {
                Document document = ((DocumentPut)op).getDocument();
                Array<StringFieldValue> stringArray = (Array<StringFieldValue>) document.getFieldValue("stringarray");

                assertArraySize(stringArray, 1);
                assertArray(stringArray, 0, new StringFieldValue("first"));

                stringArray.add(new StringFieldValue("second"));
            }
        }
        return Progress.DONE;
    }
}
