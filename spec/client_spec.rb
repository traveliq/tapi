# -*- coding: utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TAPI::V3::Client, " utility methods" do

  it 'should build a query string' do
    TAPI::Utils.append_query('url', {}).should == 'url'
    TAPI::Utils.append_query('url', {:param1 => 1, :param2 => 'zwo'}).should == 'url?param1=1&param2=zwo'
    TAPI::Utils.append_query('url?already=here', {:param1 => 1, :param2 => 'zwo'}).should == 'url?already=here&param1=1&param2=zwo'
    TAPI::Utils.append_query('url', {:array => [1,2]}).should == 'url?array[]=1&array[]=2'
    TAPI::Utils.append_query('url', {:umlaut => 'ü'}).should == 'url?umlaut=%C3%BC'
  end

  it 'should symbolize keys in a hash' do
    data_in = {'i_am' => {'a_nested' => 'hash'}, 'with' => {'an_array' => [2, 3, 4]}}
    data_out = {:i_am => {:a_nested => 'hash'}, :with => {:an_array => [2, 3, 4]}}
    TAPI::Utils.symbolize_keys(data_in).should == data_out
  end

  it 'should have a default logger' do
    TAPI::V3::Client.logger.class.should == Logger
    TAPI::V3::Client.new({}).logger.class.should == Logger
  end

  it 'should have a configurable logger' do
    logger = mock('Logger').as_null_object
    TAPI::V3::Client.logger = logger
    TAPI::V3::Client.logger.should == logger
    TAPI::V3::Client.new({}).logger.should == logger
  end

  it "should translate HTTP errors" do
    curl = mock('Curl', :response_code => 404)
    curl.stub!(:url, nil)
    curl.stub!(:body_str, nil)
    lambda {TAPI::V3::Client.check_for_errors(curl)}.should raise_error TAPI::NotFoundError
  end

  it "should raise an error for an unknown HTTP errors" do
    curl = mock('Curl', :response_code => 517)
    lambda {TAPI::V3::Client.check_for_errors(curl)}.should raise_error
  end

  it "should provide context for HTTP errors" do
    curl = mock('Curl', 
      :response_code => 412, 
      :url => 'superdope.curl', 
      :body_str => 'dead-bodies')

    error = nil

    begin
      TAPI::V3::Client.check_for_errors(curl)
    rescue TAPI::Error => e
      error = e
    end

    error.should_not be_nil
    error.response_code.should == 412
    error.response_body.should == 'dead-bodies'
    error.request_url.should == 'superdope.curl'
  end

end

describe TAPI::V3::Client, " retrieving remote data" do

  it 'should have configurable authentication' do
    TAPI::V3::Client.http_authentication.should == nil
    TAPI::V3::Client.config = {:http_user_name => 'username', :http_password => 'password'}
    TAPI::V3::Client.http_authentication.should == 'username:password'
    TAPI::V3::Client.config = nil
  end

  it 'should retrieve data via post' do
    curl = mock('Curl')
    curl.should_receive(:http_post)
    curl.should_receive(:body_str).and_return('the_body')
    JSON.should_receive(:parse).with('the_body').and_return('the_data')
    Curl::Easy.should_receive(:new).and_return(curl)
    TAPI::V3::Client.should_receive(:check_for_errors).with(curl)
    TAPI::V3::Client.should_receive(:new).with('the_data', nil, true)
    TAPI::V3::Client.new_from_post('the_url', {:a_param => :yeah})
  end

  it 'should use authentication options when posting' do
    curl = mock('Curl')
    curl.should_receive(:http_post)
    curl.should_receive(:userpwd=).with('the_authentication')
    curl.should_receive(:body_str).and_return('the_body')
    JSON.should_receive(:parse).with('the_body').and_return('the_data')
    Curl::Easy.should_receive(:new).and_return(curl)
    TAPI::V3::Client.should_receive(:http_authentication).and_return('the_authentication')
    TAPI::V3::Client.should_receive(:check_for_errors).with(curl)
    TAPI::V3::Client.should_receive(:new).with('the_data', nil, true)
    TAPI::V3::Client.new_from_post('the_url', {:a_param => :yeah})
  end

  it 'should use authentication options when getting' do
    curl = mock('Curl', :header_str => 'ETag the_etag')
    curl.should_receive(:http_get)
    curl.should_receive(:userpwd=).with('the_authentication')
    curl.should_receive(:body_str).and_return('the_body')
    JSON.should_receive(:parse).with('the_body').and_return('the_data')
    Curl::Easy.should_receive(:new).and_return(curl)
    TAPI::V3::Client.should_receive(:http_authentication).and_return('the_authentication')
    TAPI::V3::Client.should_receive(:check_for_errors).with(curl)
    TAPI::V3::Client.should_receive(:new).with('the_data', 'the_etag', true)
    TAPI::V3::Client.new_from_get('the_url', {:a_param => :yeah})
  end

  it 'should retrieve data via get without an etag given' do
    curl = mock('Curl', :header_str => 'ETag the_etag')
    curl.should_receive(:http_get)
    curl.should_receive(:body_str).and_return('the_body')
    JSON.should_receive(:parse).with('the_body').and_return('the_data')
    TAPI::Utils.should_receive(:append_query).with('the_url', {:a_param => :yeah}).and_return('the_url?a_param=yeah')
    Curl::Easy.should_receive(:new).with('the_url?a_param=yeah').and_return(curl)
    TAPI::V3::Client.should_receive(:check_for_errors).with(curl)
    TAPI::V3::Client.should_receive(:new).with('the_data', 'the_etag', true).and_return('the_client')
    TAPI::V3::Client.new_from_get('the_url', {:a_param => :yeah}).should == ['the_client', 'the_etag']
  end

  it 'should retrieve data via get with an non-matching etag given' do
    curl = mock('Curl', :header_str => 'ETag remote_etag')
    curl.should_receive(:http_get)
    curl.should_receive(:body_str).and_return('the_body')
    curl.should_receive(:headers).and_return({})
    JSON.should_receive(:parse).with('the_body').and_return('the_data')
    TAPI::Utils.should_receive(:append_query).with('the_url', {:a_param => :yeah}).and_return('the_url?a_param=yeah')
    Curl::Easy.should_receive(:new).with('the_url?a_param=yeah').and_return(curl)
    TAPI::V3::Client.should_receive(:check_for_errors).with(curl)
    TAPI::V3::Client.should_receive(:new).with('the_data', 'remote_etag', true).and_return('the_client')
    TAPI::V3::Client.new_from_get('the_url', {:a_param => :yeah}, 'etag').should == ['the_client', 'remote_etag']
  end

  it 'should retrieve data via get with no etag given' do
    curl = mock('Curl', :header_str => 'nothing in here')
    curl.should_receive(:http_get)
    curl.should_receive(:body_str).and_return('the_body')
    curl.should_receive(:headers).and_return({})
    JSON.should_receive(:parse).with('the_body').and_return('the_data')
    TAPI::Utils.should_receive(:append_query).with('the_url', {:a_param => :yeah}).and_return('the_url?a_param=yeah')
    Curl::Easy.should_receive(:new).with('the_url?a_param=yeah').and_return(curl)
    TAPI::V3::Client.should_receive(:check_for_errors).with(curl)
    TAPI::V3::Client.should_receive(:new).with('the_data', nil, true).and_return('the_client')
    TAPI::V3::Client.new_from_get('the_url', {:a_param => :yeah}, 'etag').should == ['the_client', nil]
  end

  it 'should retrieve data via get with an matching etag given' do
    curl = mock('Curl', :header_str => 'ETag the_etag')
    curl.should_receive(:http_get)
    curl.should_not_receive(:body_str)
    curl.should_receive(:headers).and_return({})
    JSON.should_not_receive(:parse)
    TAPI::Utils.should_receive(:append_query).with('the_url', {:a_param => :yeah}).and_return('the_url?a_param=yeah')
    Curl::Easy.should_receive(:new).with('the_url?a_param=yeah').and_return(curl)
    TAPI::V3::Client.should_receive(:check_for_errors).with(curl)
    TAPI::V3::Client.should_not_receive(:new)
    TAPI::V3::Client.new_from_get('the_url', {:a_param => :yeah}, 'the_etag').should == [nil, 'the_etag']
  end

end

TAPI::V3::Data = Class.new(TAPI::V3::Client)
TAPI::V3::NewClient = Class.new
TAPI::V3::ArrayHashElement = Class.new(TAPI::V3::Client)

describe TAPI::V3::Client, " dynamic methods" do
  
  before(:each) do
    @data_hash = {
      :search =>
      {
        :resources =>
        {
          :remote1_url => 'remote1_url',
          :remote2_url => 'remote2_url'
        },
        :data =>
        {
          :a_hash => {:some => :data},
          :array_elements => [1, 2, 3],
          :a_value => 'value',
          :nil => nil,
          :array_hash_elements => [{:the => :one}, {:the => :other}]
        }
      }
    }

    @client = TAPI::V3::Client.new(@data_hash, nil, true)
    @client.class_mapping[:some_key] = TAPI::V3::NewClient
    @client.class_mapping[:data] = TAPI::V3::Data
    @client.class_mapping[:array_hash_elements] = TAPI::V3::ArrayHashElement

    def @client.remote_cache=(v)
      @remote_cache = v
    end
  end
  
  it 'should return the initial hash' do
    @client.to_hash.should == @data_hash
  end
  
  it 'should raise an error when a unknown method is called' do
    lambda {@client.search.giveme}.should raise_error NoMethodError
  end

  it 'should return nil if a key is present but value is nil' do
    @client.search.data.nil.should == nil
  end
  
  it 'should raise an error when a unknown method is called' do
    lambda {@client.search.fetch_giveme}.should raise_error NoMethodError
  end
  
  it 'should instanciate a new client with a sub-hash' do
    @client.search.class.should == TAPI::V3::Client
  end

  it 'should instanciate a new client with a sub-sub-hash' do
    @client.search.data.to_hash.should == @data_hash[:search][:data]
  end

  it 'should return a plain value' do
    @client.search.data.a_value.should == 'value'
  end

  it 'should not shortcut to a multiple subdocuments' do
    client = TAPI::V3::Client.new(:key => { :value => 'value' }, :second => { :value => 'value' })
    lambda { client.value }.should raise_error NoMethodError
  end

  it 'should instanciate a set of new client with an array' do
    @client.search.data.array_elements == [1, 2, 3]
  end

  it 'should know its attributes' do
    @client.attributes == ['search']
    @client.search.attributes == ['resources', 'data']
  end
  
  it 'should know its urls' do
    expect = {:remote1_url => 'remote1_url', :remote2_url => 'remote2_url'}
    @client.urls.should == expect
    @client.urls.should == expect
    @client.search.data.urls.should == {}
  end
  
  it 'should know its urls' do
    @client.remote_calls.should == ["fetch_remote1", "fetch_remote2"]
  end
  
  it 'should be able to call a remote method' do
    @client.should_receive(:get).with('remote1_url', TAPI::V3::Client, {})
    @client.fetch_remote1
  end
  
  it 'should be able to call a remote method with options' do
    options = {:please_consider => :this}
    @client.should_receive(:get).with('remote1_url', TAPI::V3::Client, options)
    @client.fetch_remote1(options)
  end

  it 'should find a client class' do    
    @client.send(:client_class, 'some_key').should == TAPI::V3::NewClient
  end

  it 'should instanciate with a client class' do
    @client.search.data.class.should == TAPI::V3::Data
  end

  it 'should instanciate with an array of client classes' do
    array = @client.search.data.array_hash_elements
    array.length.should == 2
    array.map(&:class).uniq.should == [TAPI::V3::ArrayHashElement]
  end

  it 'should generate url keys' do
    @client.send(:url_key, 'lala').should == nil
    @client.send(:url_key, 'fetch_lala').should == 'lala'
  end

  it 'should generate cache keys' do
    k1 = @client.send(:cache_key, 'url1', {:opt1 => 1})
    k2 = @client.send(:cache_key, 'url1', {:opt1 => 1, :opt2 => 2})
    k3 = @client.send(:cache_key, 'url1', {:opt2 => 2, :opt1 => 1})
    k1.should_not == k2
    k2.should == k3
  end

  it 'should get data from remote if the cache is empty' do
    @client.remote_cache = {}
    @client.class.should_receive(:new_from_get).with('the_url', {:instanciate_as => 'the_class'}, nil).and_return(['remote_data', 'remote_etag'])
    @client.send(:get, 'the_url', 'the_class').should == 'remote_data'
  end
  
  it 'should get data from cache if it is cached' do
    @client.stub!(:cache_key => 'the_key')
    @client.remote_cache = {'the_key' => {:etag => 'the_etag', :data => 'cached_data'}}
    @client.class.should_receive(:new_from_get).with('the_url', {:instanciate_as => 'the_class'}, 'the_etag').and_return(['remote_data', 'the_etag'])
    @client.send(:get, 'the_url', 'the_class').should == 'cached_data'
  end

  it 'should return a cached reply if :skip_refresh option is given' do
    @client.stub!(:cache_key => 'the_key')
    @client.remote_cache = {'the_key' => {:etag => 'the_etag', :data => 'cached_data'}}
    @client.class.should_not_receive(:new_from_get)
    @client.send(:get, 'the_url', 'the_class', :skip_refresh => true).should == 'cached_data'
  end
  
  it 'should get data from remote if the etag is not in the cache' do
    @client.stub!(:cache_key => 'the_key')
    @client.remote_cache = {'the_key' => {:etag => 'local_etag', :data => 'cached_data'}}
    @client.class.should_receive(:new_from_get).with('the_url', {:instanciate_as => 'the_class'}, 'local_etag').and_return(['remote_data', 'remote_etag'])
    @client.send(:get, 'the_url', 'the_class').should == 'remote_data'
  end
  
end

