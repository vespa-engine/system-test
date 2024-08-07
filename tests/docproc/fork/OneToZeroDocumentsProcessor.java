// Copyright Vespa.ai. All rights reserved.
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
