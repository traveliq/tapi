require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe TAPI::V3::Configurable, " configuration" do
  before(:each) do
    @klass = Class.new
    @klass.send(:include, TAPI::V3::Configurable)
  end
  
  it 'should not raise an error if it is configured' do
    @klass.config = {}
    lambda { @klass.config }.should_not raise_error
  end
  
  it 'should remember its configuration' do
    config = {:config_data => :it_is}
    @klass.config = config
    @klass.config.should == config
  end
  
  it 'should make the configuration accesible to its instances' do
    config = {:config_data => :it_is}
    @klass.config = config
    @klass.new.config.should == config
  end
  
end
  