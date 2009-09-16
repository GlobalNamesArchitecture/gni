require File.dirname(__FILE__) + '/../spec_helper'

describe '/parsers' do
  
  describe 'index' do
    it 'should render' do
      res = request('/parsers.xml?names=Betula%20verucosa;Parus+major')
      res.success?.should be_true
      res.body.should have_tag('scientific_name')
      res = request('/parsers.json?names=Betuls+verucosa&callback=myfunc')
      res.success?.should be_true
      res.body.should include('myfunc([')
    end
  end
  
  describe 'new' do
    it 'should render' do
      res = request('/parsers/new')
      res.success?.should be_true
      res.body.should have_tag('form[action="/parsers"]') do
        with_tag('textarea#names')
        with_tag('input[value="Submit"]')
      end
    end
  end
  
  describe 'create' do
    it 'should render json' do
      res = request('/parsers', :params =>{
        'names' => "Betula pubescens\nPlantago major L. 1786",
        'format' => 'json'})
      res.success?.should be_true
      JSON.load(res.body).size.should == 2
      res.body.should include('"parsed":true')
    end
    
    it 'should render html' do
      res = request('/parsers', :params =>{
        'names' => "Betula pubescens\nPlantago major L. 1786",
        'format' => 'html'})
      res.success?.should be_true
      res.body.should include('<span class="tree_key">parsed: </span>true')
    end
  end
end
