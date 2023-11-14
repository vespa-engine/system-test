// Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package test;

public class BarComponent extends com.yahoo.component.AbstractComponent {
    
  private final BazComponent bazComponent;
  private final com.yahoo.jdiscinclude.TestConfig cfg;
  
  @com.google.inject.Inject
  public BarComponent(BazComponent bazComponent, com.yahoo.jdiscinclude.TestConfig cfg) {
      this.bazComponent=bazComponent;      
      this.cfg=cfg;
  }
  
  public String bar() { return cfg.testString()+bazComponent.baz(); }

}