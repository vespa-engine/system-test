// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest.order;

import com.yahoo.docproc.DocumentProcessor;
import com.yahoo.document.datatypes.Array;
import com.yahoo.document.datatypes.StringFieldValue;

/**
 * @author Einar M R Rosenvinge
 */
public abstract class OrderDocumentProcessor extends DocumentProcessor {

    protected void assertArraySize(Array<StringFieldValue> stringArray, int correctSize) {
        if (stringArray.size() != correctSize) {
            throw new RuntimeException(this + " found array with size " + stringArray.size() + " for field 'stringarray', order must be wrong");
        }

    }

    protected void assertArray(Array<StringFieldValue> stringArray, int index, StringFieldValue correctString) {
        if (!stringArray.get(index).equals(correctString)) {
            throw new RuntimeException(this + " found element '" + stringArray.get(index) + "' at position " + index + ", order must be wrong");
        }
    }
}
