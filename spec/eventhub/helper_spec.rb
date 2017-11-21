require 'spec_helper'

RSpec.describe Eventhub::Helper do

  context 'name from class' do

    it 'gets class name' do
      class Eventhub::Test
      end

      a_class = Eventhub::Test.new
      expect(Eventhub::Helper.get_name_from_class(a_class)).to eq('test')
    end

    it 'gets class name 2' do
      class Eventhub::Test::Test
      end

      a_class = Eventhub::Test::Test.new
      expect(Eventhub::Helper.get_name_from_class(a_class)).to eq('test.test')
    end

    it 'gets class name with camel case name' do
      class Eventhub::Test::TestClass
      end

      a_class = Eventhub::Test::TestClass.new
      expect(Eventhub::Helper.get_name_from_class(a_class)).to eq('test.test_class')
    end

    it 'get class name without eventhub module' do
      module Test
        class Test
        end
      end

      a_class = Test::Test.new
      expect(Eventhub::Helper.get_name_from_class(a_class)).to eq('test.test')
    end

  end
end
