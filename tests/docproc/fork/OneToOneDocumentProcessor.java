// Copyright Vespa.ai. All rights reserved.
package com.yahoo.vespatest;

import java.util.List;
import com.yahoo.docproc.*;
import com.yahoo.document.*;

public class OneToOneDocumentProcessor extends DocumentProcessor {

    @Override
    public Progress process(Processing processing) {
	return Progress.DONE;
    }

}
