require 'spec_helper'

RSpec.describe EventHub::Helper do
  include EventHub::Helper

  context 'name from class' do

    it 'gets class name' do
      class EventHub::Test
      end

      a_class = EventHub::Test.new
      expect(get_name_from_class(a_class)).to eq('test')
    end

    it 'gets class name 2' do
      class EventHub::Test::Test
      end

      a_class = EventHub::Test::Test.new
      expect(get_name_from_class(a_class)).to eq('test.test')
    end

    it 'gets class name with camel case name' do
      class EventHub::Test::TestClass
      end

      a_class = EventHub::Test::TestClass.new
      expect(get_name_from_class(a_class)).to eq('test.test_class')
    end

    it 'get class name without eventhub module' do
      module Test
        class Test
        end
      end

      a_class = Test::Test.new
      expect(get_name_from_class(a_class)).to eq('test.test')
    end
  end

  context 'stamp' do

    it 'give actual time in UTC format' do
      expect(now_stamp).to match(/^\d{4,4}-\d{2,2}-\d{2,2}T\d{2,2}:\d{2,2}:\d{2,2}.\d{5,6}Z/)
    end

    it 'gives given time in UTC format' do
      time = Time.utc(2017,1,2,3,4,5.123456)
      expect(now_stamp(time)).to match(/^2017-01-02T03:04:05.123456Z/)
    end
  end

  context 'bunny_connection_properties' do
    it 'returns hash' do
      h = bunny_connection_properties
      expect(h.class).to eq(Hash)
    end
  end
end
