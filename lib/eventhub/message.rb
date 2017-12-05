module EventHub

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
      name = header.gsub(/\./,"_")

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
      Message.new({ "status" =>  { "code" => STATUS_INVALID, "message" => "JSON parse error: #{e}" }} ,{ "original_message_base64_encoded" => Base64.encode64(raw)},raw)
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
      REQUIRED_HEADERS.all? { |key| @header.all_keys_with_path.include?(key) && !!self.send(key.gsub(/\./,"_").to_sym)}
    end

    def success?
      self.status_code == STATUS_SUCCESS
    end

    def retry?
      self.status_code == STATUS_RETRY
    end

    def initial?
      self.status_code == STATUS_INITIAL
    end

    def retry_pending?
      self.status_code == STATUS_RETRY_PENDING
    end

    def invalid?
      self.status_code == STATUS_INVALID
    end

    def schedule?
      self.status_code == STATUS_SCHEDULE
    end

    def schedule_retry?
      self.status_code == STATUS_SCHEDULE_RETRY
    end

    def schedule_pending?
      self.status_code == STATUS_SCHEDULE_PENDING
    end

    def to_json
      {'header' => self.header, 'body' => self.body}.to_json
    end

    def to_s
      "Msg: process [#{self.process_name},#{self.process_step_position},#{self.process_execution_id}], status [#{self.status_code},#{self.status_message},#{self.status_retried_count}]"
    end

    # copies the message and set's provided status code (default: success), actual stamp, and a new message id
    def copy(status_code = STATUS_SUCCESS)

      # use Marshal dump and load to make a deep object copy
      copied_header = Marshal.load( Marshal.dump(header))
      copied_body   = Marshal.load( Marshal.dump(body))

      copied_header.set("message_id",UUIDTools::UUID.timestamp_create.to_s)
      copied_header.set("created_at",now_stamp)
      copied_header.set("status.code",status_code)

      Message.new(copied_header, copied_body)
    end

    def append_to_execution_history(processor_name)
      unless header.get('execution_history')
        header.set('execution_history', [])
      end
      header.get('execution_history') << {'processor' => processor_name, 'timestamp' => now_stamp}
    end

    def self.translate_status_code(code)
      case code
        when EventHub::STATUS_INITIAL            then return 'STATUS_INITIAL'
        when EventHub::STATUS_SUCCESS            then return 'STATUS_SUCCESS'
        when EventHub::STATUS_RETRY              then return 'STATUS_RETRY'
        when EventHub::STATUS_RETRY_PENDING      then return 'STATUS_RETRY_PENDING'
        when EventHub::STATUS_INVALID            then return 'STATUS_INVALID'
        when EventHub::STATUS_DEADLETTER         then return 'STATUS_DEADLETTER'
        when EventHub::STATUS_SCHEDULE           then return 'STATUS_SCHEDULE'
        when EventHub::STATUS_SCHEDULE_RETRY     then return 'STATUS_SCHEDULE_RETRY'
        when EventHub::STATUS_SCHEDULE_PENDING   then return 'STATUS_SCHEDULE_PENDING'
      end
    end

  end

end
