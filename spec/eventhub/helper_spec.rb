require 'spec_helper'

RSpec.describe EventHub::Helper do

  context 'name from class' do

    it 'gets class name' do
      class EventHub::Test
      end

      a_class = EventHub::Test.new
      expect(EventHub::Helper.get_name_from_class(a_class)).to eq('test')
    end

    it 'gets class name 2' do
      class EventHub::Test::Test
      end

      a_class = EventHub::Test::Test.new
      expect(EventHub::Helper.get_name_from_class(a_class)).to eq('test.test')
    end

    it 'gets class name with camel case name' do
      class EventHub::Test::TestClass
      end

      a_class = EventHub::Test::TestClass.new
      expect(EventHub::Helper.get_name_from_class(a_class)).to eq('test.test_class')
    end

    it 'get class name without eventhub module' do
      module Test
        class Test
        end
      end

      a_class = Test::Test.new
      expect(EventHub::Helper.get_name_from_class(a_class)).to eq('test.test')
    end
  end
end
