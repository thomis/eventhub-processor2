# EventHub module
module EventHub
  # BaseException class
  class BaseException < RuntimeError
    attr_accessor :code, :message
    def initialize(message=nil, code=EventHub::STATUS_DEADLETTER)
      @message = message
      @code    = code
      super(@message)
    end
  end
end
