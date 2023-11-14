# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

require 'ffi'

class ProcessCtrl
  module LibC
    PR_SET_THP_DISABLE = 41
    PR_GET_THP_DISABLE = 42

    extend FFI::Library
    ffi_lib FFI::Platform::LIBC
    attach_function :prctl, [:int, :long, :long, :long, :long], :int
  end

  class << self
    def set_thp_disable(value)
      LibC.prctl(LibC::PR_SET_THP_DISABLE, value, 0, 0, 0)
    end
    def get_thp_disable
      LibC.prctl(LibC::PR_GET_THP_DISABLE, value, 0, 0, 0)
    end
  end
end
