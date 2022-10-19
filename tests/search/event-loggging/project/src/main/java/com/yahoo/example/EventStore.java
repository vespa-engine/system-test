// Copyright Yahoo. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.example;

import com.yahoo.component.AbstractComponent;
import java.util.ArrayList;
import java.util.List;

/**
 * @author musum
 */
public class EventStore extends AbstractComponent {

    private final List<String> events = new ArrayList<>();

    public void add(String event) {
        events.add(event);
    }

    public int getEventCount() {
        return events.size();
    }

}
