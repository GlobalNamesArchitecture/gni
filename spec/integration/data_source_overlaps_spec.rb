require File.dirname(__FILE__) + '/../spec_helper'

describe '/data_source_overlaps' do
  before :all do
    EolScenario.load :application
    DataSourceOverlap.find_all_overlaps
  end

  after :all do
    truncate_all_tables
  end

  it "should render" do
    visit('/data_sources/3/data_source_overlaps')
    page.status_code.should == 200
    body.should include("Name Bank")
  end

  it "should render after deletion of a repository (Bug: TAX-197)" do
    count = DataSource.count
    DataSource.last.destroy
    DataSource.count.should == count -1
    visit('/data_sources/3/data_source_overlaps')
    page.status_code.should == 200
    body.should include("Name Bank")
  end
end