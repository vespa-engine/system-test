# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
require "rexml/document"
require "simpledocument.rb"

class GatewayXMLParser
  attr_accessor :documents
  attr_accessor :continuation

  def initialize(buffer)
     @documents = []

     doc = REXML::Document.new(buffer)
     doc.elements.each("result/document") { |element|
       sd = SimpleDocument.new(element.attributes["documenttype"],
	 element.attributes["documentid"],
	 buffer)

       element.elements.each { |elem|
         if (elem.has_elements?)
           val=[]

           elem.each_element { |e|
             if (e.attributes["weight"])
               val.push([e.text, e.attributes["weight"]])
             else
               val.push(e.text)
             end
           }

	   sd.add_field(elem.name, val)
         else
           sd.add_field(elem.name, elem.text)
         end
       }

       documents.push(sd)
     }
     doc.elements.each("result/remove") { |element|
       sd = SimpleDocument.new(nil,
         element.attributes["documentid"],
	 buffer)
       sd.removetime = element.attributes["removetime"]
       sd.isremove = true
       documents.push(sd)
     }

     doc.elements.each("result/continuation") { |element|
       @continuation = element.text
     }
  end
end
