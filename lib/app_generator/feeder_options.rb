# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
class FeederOptions
  include ChainedSetter

  chained_setter :abort_on_document_error
  chained_setter :timeout
  chained_setter :max_pending_bytes
  chained_setter :max_pending_docs

  def abortondocumenterror(abort_on_document_error)
    @abort_on_document_error = abort_on_document_error
    self
  end

  def timeout(timeout)
    @timeout = timeout
    self
  end

  def to_xml(indent)
    XmlHelper.new(indent).
        tag("abortondocumenterror").content(@abort_on_document_error).close_tag.
        tag("timeout").content(@timeout).close_tag.
        tag("maxpendingbytes").content(@max_pending_bytes).close_tag.
        tag("maxpendingdocs").content(@max_pending_docs).close_tag.
        to_s
  end
end
