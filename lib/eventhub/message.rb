# EventHub module
module EventHub
  # Message class
  class Message
    include Helper

    VERSION = '1.0.0'

    # Headers that are required (value can be nil) in order to pass valid?
    REQUIRED_HEADERS = [
      'message_id',
      'version',
      'created_at',
      'origin.module_id',
      'origin.type',
      'origin.site_id',
      'process.name',
      'process.step_position',
      'process.execution_id',
      'status.retried_count',
      'status.code',
      'status.message'
    ]

    attr_accessor :header, :body, :raw, :vhost, :routing_key

    # Build accessors for all required headers
    REQUIRED_HEADERS.each do |header|
      name = header.tr('.','_')

      define_method(name) do
        self.header.get(header)
      end

      define_method("#{name}=") do |value|
        self.header.set(header,value)
      end
    end

    def self.from_json(raw)
      data = JSON.parse(raw)
      Message.new(data.get('header'), data.get('body'),raw)
    rescue => e
      Message.new(
        {
          'status' =>
          {
            'code' => STATUS_INVALID,
            'message' => "JSON parse error: #{e}"
          }
        },
        {
          'original_message_base64_encoded' => Base64.encode64(raw)
        },
        raw
      )
    end

    def initialize(header = nil, body = nil, raw = nil)
      @header = header || {}
      @body   = body || {}
      @raw    = raw

      # set message defaults, that we have required headers
      @header.set('message_id', UUIDTools::UUID.timestamp_create.to_s, false)
      @header.set('version', VERSION, false)
      @header.set('created_at', now_stamp, false)

      @header.set('origin.module_id', 'undefined', false)
      @header.set('origin.type', 'undefined', false)
      @header.set('origin.site_id', 'undefined', false)

      @header.set('process.name', 'undefined', false)
      @header.set('process.execution_id', UUIDTools::UUID.timestamp_create.to_s, false)
      @header.set('process.step_position', 0, false)

      @header.set('status.retried_count', 0, false)
      @header.set('status.code', STATUS_INITIAL, false)
      @header.set('status.message', '', false)
    end

    def valid?
      # check for existence and defined value
      REQUIRED_HEADERS.all? do |key|
        @header.all_keys_with_path.include?(key) &&
        !self.send(key.tr('.','_').to_sym).nil?
      end
    end

    def success?
      status_code == STATUS_SUCCESS
    end

    def retry?
      status_code == STATUS_RETRY
    end

    def initial?
      status_code == STATUS_INITIAL
    end

    def retry_pending?
      status_code == STATUS_RETRY_PENDING
    end

    def invalid?
      status_code == STATUS_INVALID
    end

    def schedule?
      status_code == STATUS_SCHEDULE
    end

    def schedule_retry?
      status_code == STATUS_SCHEDULE_RETRY
    end

    def schedule_pending?
      status_code == STATUS_SCHEDULE_PENDING
    end

    def to_json
      {'header' => self.header, 'body' => self.body}.to_json
    end

    def to_s
      "Msg: process "\
        "[#{process_name}, #{process_step_position}, #{process_execution_id}]"\
        ", status [#{status_code},#{status_message},#{status_retried_count}]"
    end

    # copies the message and set's provided status code (default: success), actual stamp, and a new message id
    def copy(status_code = STATUS_SUCCESS)
      # use Marshal dump and load to make a deep object copy
      copied_header = Marshal.load( Marshal.dump(header))
      copied_body   = Marshal.load( Marshal.dump(body))

      copied_header.set('message_id', UUIDTools::UUID.timestamp_create.to_s)
      copied_header.set('created_at', now_stamp)
      copied_header.set('status.code', status_code)

      Message.new(copied_header, copied_body)
    end

    def append_to_execution_history(processor_name)
      header.set('execution_history', []) unless \
        header.get('execution_history')
      header.get('execution_history') << \
        {'processor' => processor_name, 'timestamp' => now_stamp}
    end

    def self.translate_status_code(code)
      STATUS_CODE_TRANSLATION[code]
    end
  end
end
