// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package test;

public class FooComponent extends com.yahoo.component.AbstractComponent {
    
  private final com.yahoo.jdiscinclude.TestConfig cfg;

  @com.google.inject.Inject
  public FooComponent(com.yahoo.jdiscinclude.TestConfig cfg) {
      this.cfg=cfg;
  }
  
  public String foo() { return cfg.testString(); }

}