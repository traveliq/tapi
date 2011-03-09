require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'date'

describe TAPI::V3::Flights::Search, " validations" do
  before(:each) do
    @params = {
      :leaves_on => "01.01.#{Date.today.year + 1}",
      :returns_on => "01.02.#{Date.today.year + 1}",
      :origin => 'BLI',
      :destination => 'BLA',
      :adults => 1,
      :children => 0,
      :infants => 0,
      :comfort => 'E'
    }
    @search = TAPI::V3::Flights::Search.new(@params)

    TAPI::V3::Flights::Search.new(@params)
  end

  it "should be valid" do
    @search.should be_valid
  end
  
  it "should not accept dates in the past" do
    @search.leaves_on = Date.today - 1
    @search.should_not be_valid
  end
  
  it "should not accept returns before the leaving date" do
    @search.leaves_on = Date.today + 5
    @search.returns_on = Date.today + 3
    @search.should_not be_valid
  end

  it "should accept one way flights" do
    @search.leaves_on = Date.today + 5
    @search.returns_on = nil
    @search.one_way = true
    @search.should be_valid
  end

  it "should not accept missing dates" do
    @search.leaves_on = Date.today + 5
    @search.returns_on = 'asdkjhsadd'
    @search.one_way = false
    @search.should_not be_valid
  end

  it "should not accept wrong infants" do
    @search.infants = 3
    @search.adults = 1
    @search.should_not be_valid
  end
  
  it "should accept ISO date format" do
    @search.leaves_on = (Date.today + 1.day).to_s
    @search.should be_valid
  end
  
end

describe TAPI::V3::Flights::Search, " starting" do
  before(:each) do
#    TAPI::V3::Flights::Search.config = {:host => 'staging-apiv3.travel-iq.com', :port => 80, :path => '/api/v3', :key => 'traveliq'}

#    TAPI::V3::Flights::Search.config = {:host => 'host', :port => 1, :path => 'path', :key => 'key'}
    @params = {
      :leaves_on => "01.01.#{Date.today.year + 1}",
      :returns_on => "01.02.#{Date.today.year + 1}",
      :origin => 'BLI',
      :destination => 'BLA',
      :adults => 1,
      :children => 0,
      :infants => 0,
      :comfort => 'E'
    }
    @search = TAPI::V3::Flights::Search.new(@params)
  end
  
  it 'should instanciate a client' do
    @search.should_receive(:post_url).and_return('the url')
    @search.should_receive(:config).and_return({:key => 'the key'})
    client_params = {
      :leaves_on => "#{Date.today.year + 1}-01-01",
      :returns_on => "#{Date.today.year + 1}-02-01",
      :origin => 'BLI',
      :destination => 'BLA',
      :adults => 1,
      :children => 0,
      :infants => 0,
      :comfort => 'E',
      :format => 'json',
      :one_way => false,
      :key=>"the key"
    }
    client = mock('Client', :to_hash => 'the resources').as_null_object
    TAPI::V3::Client.should_receive(:new_from_post).with('the url', client_params).and_return(client)
    @search.start!
  end
end
