// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.vespatest;

import java.util.List;
import com.yahoo.docproc.*;
import com.yahoo.document.*;

public class OneToZeroDocumentsProcessor extends DocumentProcessor {

    @Override
    public Progress process(Processing processing) {
        processing.getDocumentOperations().clear();
        return Progress.DONE;
    }

}
