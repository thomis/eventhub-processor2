require "spec_helper"

RSpec.describe EventHub::Statistics do
  let(:statistics) { EventHub::Statistics.new }

  it "increments the successful message counter" do
    expect { statistics.success(0, 0) }.to change { statistics.messages_successful }
  end

  it "increments the unsuccessful message counter" do
    expect { statistics.failure }.to change { statistics.messages_unsuccessful }
  end

  it "calculates the average size" do
    expect(statistics.messages_average_size).to eq(0)

    statistics.success(0, 10)
    expect(statistics.messages_average_size).to eq(10.0)

    statistics.success(0, 30)
    expect(statistics.messages_average_size).to eq(20.0)

    statistics.success(0, 15)
    expect(statistics.messages_average_size).to eq(55 / 3.0)
  end

  it "calculates the average process time" do
    expect(statistics.messages_average_process_time).to eq(0)

    statistics.success(10, 0)
    expect(statistics.messages_average_process_time).to eq(10.0)

    statistics.success(30, 0)
    expect(statistics.messages_average_process_time).to eq(20.0)

    statistics.success(15, 0)
    expect(statistics.messages_average_process_time).to eq(55 / 3.0)
  end

  it "reraises exceptions" do
  end

  it "measures success" do
    statistics.measure(10) do
      # nothing here
    end
    expect(statistics.messages_average_size).to eq(10.0)
    expect(statistics.messages_successful).to eq(1)
  end

  it "measures failure" do
    begin
      statistics.measure(10) do
        raise "increment failure, please"
      end
    rescue
      # ignore
    end
    expect(statistics.messages_unsuccessful).to eq(1)
  end
end
