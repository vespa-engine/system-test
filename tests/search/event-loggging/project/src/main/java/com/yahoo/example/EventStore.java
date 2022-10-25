package com.yahoo.example;

public interface EventStore {

    void add(String event);

    int getEventCount();

}
