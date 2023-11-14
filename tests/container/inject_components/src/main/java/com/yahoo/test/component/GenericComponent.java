// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test.component;

public class GenericComponent {
    public final String message;

    public GenericComponent(NestedGenericComponent nested) {
        message = "GenericComponent got " + nested.message;
    }
}
