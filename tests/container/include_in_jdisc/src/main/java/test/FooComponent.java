// Copyright Vespa.ai. All rights reserved.
package test;

public class FooComponent extends com.yahoo.component.AbstractComponent {
    
  private final com.yahoo.jdiscinclude.TestConfig cfg;

  @com.google.inject.Inject
  public FooComponent(com.yahoo.jdiscinclude.TestConfig cfg) {
      this.cfg=cfg;
  }
  
  public String foo() { return cfg.testString(); }

}