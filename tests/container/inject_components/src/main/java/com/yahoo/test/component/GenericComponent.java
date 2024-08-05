// Copyright Vespa.ai. All rights reserved.
package com.yahoo.test.component;

public class GenericComponent {
    public final String message;

    public GenericComponent(NestedGenericComponent nested) {
        message = "GenericComponent got " + nested.message;
    }
}
