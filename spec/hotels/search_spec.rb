require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'date'

describe TAPI::V3::Hotels::Search, " validations" do
  before(:each) do
    @params = {
      :arrival_date => "01.01.#{Date.today.year + 1}",
      :departure_date => "01.02.#{Date.today.year + 1}",
      :city_id => 1,
      :single_rooms_count => 1,
      :double_rooms_count => 2
    }
    @search = TAPI::V3::Hotels::Search.new(@params)
  end

  it "should be valid with city" do
    @search.should be_valid
  end

  it "should be valid with region" do
    @params[:city_id] = nil
    @params[:region_id] = 1
    @params[:hotel_id] = nil
    @search = TAPI::V3::Hotels::Search.new(@params)
    @search.should be_valid
  end

  it "should be valid with hotel" do
    @params[:city_id] = nil
    @params[:region_id] = nil
    @params[:hotel_id] = 1
    @search = TAPI::V3::Hotels::Search.new(@params)
    @search.should be_valid
  end

  @params = {
    :arrival_date => "01.01.#{Date.today.year + 1}",
    :departure_date => "01.02.#{Date.today.year + 1}",
    :city_id => 1,
    :single_rooms_count => 1,
    :double_rooms_count => 2
  }

  [:arrival_date, :departure_date].each do |key|
    it "should be invalid when #{key} has some stupid value" do
      params = @params.dup
      params[key] = 'schnabu'
      TAPI::V3::Hotels::Search.new(params).should_not be_valid
    end
  end
  
  it "should accept room configurations" do    
    search = TAPI::V3::Hotels::Search.new

    lambda { search.room_configuration = '[A|2]' }.should_not raise_error
    lambda { search.room_configuration = '[A|13][A|2|12][A]' }.should_not raise_error
  end

  it "should not accept invalid room configurations" do
    lambda { search.room_configuration = '[A|2]x' }.should raise_error
    lambda { search.room_configuration = '[X]' }.should raise_error
    lambda { search.room_configuration = '[A][A][B]' }.should raise_error
    lambda { search.room_configuration = '[A][A][A][A][A][A][A]' }.should raise_error
  end

  it "should accept ISO date format" do
    TAPI::V3::Hotels::Search.new(@params.merge(:arrival_date => Date.today.to_s)).should be_valid
  end
  
  it "should accept date objects" do
    TAPI::V3::Hotels::Search.new(@params.merge(:arrival_date => Date.today)).should be_valid
  end
  
end

describe TAPI::V3::Hotels::Search, " starting" do
  before(:each) do
#    TAPI::V3::Hotels::Search.config = {:host => 'staging-apiv3.travel-iq.com', :port => 80, :path => '/api/v3', :key => 'traveliq'}

    TAPI::V3::Hotels::Search.config = {:host => 'host', :port => 1, :path => 'path', :key => 'key'}
    @params = {
      :arrival_date => "01.01.#{Date.today.year + 1}",
      :departure_date => "01.02.#{Date.today.year + 1}",
      :city_id => 1,
      :single_rooms_count => 1,
      :double_rooms_count => 2
    }
    @search = TAPI::V3::Hotels::Search.new(@params)
  end
  
  it 'should instanciate a client' do
    @search.should_receive(:post_url).and_return('the url')
    @search.should_receive(:config).and_return({:key => 'the key'})
    client_params = {
      :key => 'the key',
      :format => 'json',
      :arrival_date => "#{Date.today.year + 1}-01-01",
      :departure_date => "#{Date.today.year + 1}-02-01",
      :city_id => 1,
      :region_id => nil,
      :hotel_id => nil,
      :room_configuration => '[A][A|A][A|A]'
    }
    client = mock('Client', :resources => 'the resources').as_null_object
    TAPI::V3::Client.should_receive(:new_from_post).with('the url', client_params).and_return(client)
    # @search.should_receive(:load_client)
    @search.start!
  end
end

describe TAPI::V3::Hotels::Search, " hotel_searches" do
    before(:each) do
    TAPI::V3::Hotels::Search.config = {:host => 'host', :port => 1, :path => 'path', :key => 'key'}
    @params = {
      :arrival_date => "01.01.#{Date.today.year + 1}",
      :departure_date => "01.02.#{Date.today.year + 1}",
      :city_id => 1,
      :single_rooms_count => 1,
      :double_rooms_count => 2
    }
    @search = TAPI::V3::Hotels::Search.new(@params)
  end
  
  it 'should create a hotel search from an ID' do
    hs = @search.hotel_search(666)
    hs.arrival_date.should == Date.new(Date.today.year + 1, 1, 1)
    hs.departure_date.should == Date.new(Date.today.year + 1, 2, 1)
    hs.city_id.should == nil
    hs.room_configuration.should == '[A][A|A][A|A]'
    hs.hotel_id.should == 666
  end

  it 'should create a hotel search from an ID' do
    result = mock('Result', :hotel_id => 666)
    hs = @search.hotel_search(result)
    hs.arrival_date.should == Date.new(Date.today.year + 1, 1, 1)
    hs.departure_date.should == Date.new(Date.today.year + 1, 2, 1)
    hs.city_id.should == nil
    hs.room_configuration.should == '[A][A|A][A|A]'
    hs.hotel_id.should == 666
  end
end
