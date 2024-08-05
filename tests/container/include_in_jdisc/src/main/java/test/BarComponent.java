// Copyright Vespa.ai. All rights reserved.
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