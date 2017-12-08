require 'spec_helper'

RSpec.describe EventHub::Message do

  before(:each) do
    @m = EventHub::Message.new
  end

  context "general" do
    it "should have n required header keys" do
      expect(EventHub::Message::REQUIRED_HEADERS.size).to eq(12)
    end

    it 'shoudld have a default output' do
      expect(@m.to_s).to \
        match(/Msg: process \[undefined, 0, [0-9a-f-]+\], status \[0,,0\]/)
    end

  end

  context "initialization" do

    it "should have a valid header (structure and data)" do
      expect(@m.valid?).to eq(true)
    end

    it "should be invalid if one or more values are nil" do
      EventHub::Message::REQUIRED_HEADERS.each do |key|
        m = @m.dup
        m.header.set(key, nil, true)
        expect(m.valid?).to eq(false)
      end
    end

    it "should initialize from a json string" do

      # construct a json string
      header = {}
      body   = { "data" => "1"}

      EventHub::Message::REQUIRED_HEADERS.each do |key|
        header.set(key, "1")
      end

      json = {'header' => header, 'body' => body}.to_json

      # build message from string
      m = EventHub::Message.from_json(json)


      expect(m.valid?).to eq(true)

      EventHub::Message::REQUIRED_HEADERS.each do |key|
        expect(header.get(key)).to eq("1")
      end

    end

    it "should initialize to INVALID from an invalid json string" do
      invalid_json_string = "{klasjdkjaskdf"

      m = EventHub::Message.from_json(invalid_json_string)
      expect(m.valid?).to eq(true)

      expect(m.status_code).to eq(EventHub::STATUS_INVALID)
      expect(m.status_message).to match(/^JSON parse error/)
      expect(m.raw).to eq(invalid_json_string)
    end

    it 'should have a clear state' do
      expect(@m.initial?).to eq(true)
      expect(@m.success?).to eq(false)
      expect(@m.invalid?).to eq(false)
      expect(@m.retry_pending?).to eq(false)
    end
  end

  context "copy" do
    it "should copy the message with status success" do
      copied_message = @m.copy

      expect(copied_message.valid?).to eq(true)
      expect(copied_message.message_id).not_to eq(@m.message_id)
      expect(copied_message.created_at).not_to eq(@m.created_at)
      expect(copied_message.status_code).to eq(EventHub::STATUS_SUCCESS)

      EventHub::Message::REQUIRED_HEADERS.each do |key|
        next if key =~ /message_id|created_at|status.code/i
        expect(copied_message.header.get(key)).to eq(@m.header.get(key))
      end
    end

    it "should copy the message with status invalid" do
      copied_message = @m.copy(EventHub::STATUS_INVALID)

      expect(copied_message.valid?).to eq(true)
      expect(copied_message.message_id).not_to eq(@m.message_id)
      expect(copied_message.created_at).not_to eq(@m.created_at)
      expect(copied_message.status_code).to eq(EventHub::STATUS_INVALID)

      EventHub::Message::REQUIRED_HEADERS.each do |key|
        next if key =~ /message_id|created_at|status.code/i
        expect(copied_message.header.get(key)).to eq(@m.header.get(key))
      end
    end
  end

  context "translate status code" do
    it "should translate status code to meaningful string" do
      expect(EventHub::Message.translate_status_code(EventHub::STATUS_INITIAL)).to            eq('STATUS_INITIAL')
      expect(EventHub::Message.translate_status_code(EventHub::STATUS_SUCCESS)).to            eq('STATUS_SUCCESS')
      expect(EventHub::Message.translate_status_code(EventHub::STATUS_RETRY)).to              eq('STATUS_RETRY')
      expect(EventHub::Message.translate_status_code(EventHub::STATUS_RETRY_PENDING)).to      eq('STATUS_RETRY_PENDING')
      expect(EventHub::Message.translate_status_code(EventHub::STATUS_INVALID)).to            eq('STATUS_INVALID')
      expect(EventHub::Message.translate_status_code(EventHub::STATUS_DEADLETTER)).to         eq('STATUS_DEADLETTER')
      expect(EventHub::Message.translate_status_code(EventHub::STATUS_SCHEDULE)).to           eq('STATUS_SCHEDULE')
      expect(EventHub::Message.translate_status_code(EventHub::STATUS_SCHEDULE_RETRY)).to     eq('STATUS_SCHEDULE_RETRY')
      expect(EventHub::Message.translate_status_code(EventHub::STATUS_SCHEDULE_PENDING)).to   eq('STATUS_SCHEDULE_PENDING')
    end
  end


  context "execution history" do
    it "should have a execution history entry" do
      allow_any_instance_of(EventHub::Message).to receive(:now_stamp).and_return('a.stamp')

      # no history initially
      expect(@m.header["execution_history"]).to eq(nil)

      # add an entry
      @m.append_to_execution_history("processor_name")

      execution_history = @m.header.get("execution_history")

      expect(execution_history).not_to eq(nil)
      expect(execution_history.size).to eq(1)
      expect(execution_history[0]).to eq("processor" => "processor_name", "timestamp" => "a.stamp")

      # add 2nd entry
      allow_any_instance_of(EventHub::Message).to receive(:now_stamp).and_return('b.stamp')
      @m.append_to_execution_history("processor_name2")

      execution_history = @m.header.get("execution_history")
      expect(execution_history.size).to eq(2)
      expect(execution_history[1]).to eq("processor" => "processor_name2", "timestamp" => "b.stamp")
    end
  end

  context "retry" do
    it "should response to retry?" do
      @m.status_code = EventHub::STATUS_RETRY
      expect(@m.retry?).to eq(true)

      @m.status_code = EventHub::STATUS_SUCCESS
      expect(@m.retry?).to eq(false)

      @m.status_code = 'STATUS_RETRY'
      expect(@m.retry?).to eq(false)

      @m.status_code = 'UNKNOWN_CODE'
      expect(@m.retry?).to eq(false)

      @m.status_code = 90000
      expect(@m.retry?).to eq(false)
    end
  end

  context "schedule" do
    it "should response to schedule?" do
      expect(@m.schedule?).to eq(false)

      @m.status_code = EventHub::STATUS_SCHEDULE
      expect(@m.schedule?).to eq(true)
    end

    it "should response to schedule_retry?" do
      expect(@m.schedule_retry?).to eq(false)

      @m.status_code = EventHub::STATUS_SCHEDULE_RETRY
      expect(@m.schedule_retry?).to eq(true)
    end

    it 'should response to schedule_pending?' do
      expect(@m.schedule_pending?).to eq(false)

      @m.status_code = EventHub::STATUS_SCHEDULE_PENDING
      expect(@m.schedule_pending?).to eq(true)
    end

  end

end
