require File.dirname(__FILE__) + '/../spec_helper'

describe Parser do
  before :all do
    @parser = Parser.new
  end
  
  it 'should parse a name' do
    r = @parser.parse "Betula verucosa"
    r.should_not be_nil
    JSON.load(r.to_json).should == JSON.load("{\"scientificName\":{\"genus\":{\"epitheton\":\"Betula\"},\"verbatim\":\"Betula verucosa\",\"species\":{\"epitheton\":\"verucosa\"},\"canonical\":\"Betula verucosa\",\"normalized\":\"Betula verucosa\",\"parsed\":true}}")
  end
  
  it 'should returnd parsed false for names it cannot parse' do
    r = @parser.parse "this is a bad name"
    r.should_not be_nil
    JSON.load(r.to_json).should == JSON.load('{"scientificName":{"verbatim":"this is a bad name", "parsed":false}}')
  end
  
  it 'should convert parsed result to html' do
    r = @parser.parse "Betula verucosa"
    r.to_html.should == " <div class=\"tree\">\n  <span class=\"tree_key\">scientificName</span>\n   <div class=\"tree\">\n    <span class=\"tree_key\">canonical: </span>Betula verucosa\n   </div>\n   <div class=\"tree\">\n    <span class=\"tree_key\">verbatim: </span>Betula verucosa\n   </div>\n   <div class=\"tree\">\n    <span class=\"tree_key\">normalized: </span>Betula verucosa\n   </div>\n  <div class=\"tree\">\n   <span class=\"tree_key\">genus</span>\n    <div class=\"tree\">\n     <span class=\"tree_key\">epitheton: </span>Betula\n    </div>\n  </div>\n   <div class=\"tree\">\n    <span class=\"tree_key\">parsed: </span>true\n   </div>\n  <div class=\"tree\">\n   <span class=\"tree_key\">species</span>\n    <div class=\"tree\">\n     <span class=\"tree_key\">epitheton: </span>verucosa\n    </div>\n  </div>\n </div>\n"
  end
  
  
  it 'should parse names_list' do
    r = @parser.parse_names_list("Betula verucosa\nHomo sapiens")
    JSON.load(r).should == [{"scientificName"=>{"canonical"=>"Betula verucosa", "verbatim"=>"Betula verucosa", "normalized"=>"Betula verucosa", "genus"=>{"epitheton"=>"Betula"}, "parsed"=>true, "species"=>{"epitheton"=>"verucosa"}}}, {"scientificName"=>{"canonical"=>"Homo sapiens", "verbatim"=>"Homo sapiens", "normalized"=>"Homo sapiens", "genus"=>{"epitheton"=>"Homo"}, "parsed"=>true, "species"=>{"epitheton"=>"sapiens"}}}]
    r = @parser.parse_names_list("Betula verucosa\nHomo sapiens",'xml')
    r.should == "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<scientific_names>\n  <scientific_name>\n   <node>\n    <node_key>scientificName</node_key>\n     <node>\n      <node_key>canonical: </node_key><node_value>Betula verucosa</node_value>\n     </node>\n     <node>\n      <node_key>verbatim: </node_key><node_value>Betula verucosa</node_value>\n     </node>\n     <node>\n      <node_key>normalized: </node_key><node_value>Betula verucosa</node_value>\n     </node>\n    <node>\n     <node_key>genus</node_key>\n      <node>\n       <node_key>epitheton: </node_key><node_value>Betula</node_value>\n      </node>\n    </node>\n     <node>\n      <node_key>parsed: </node_key><node_value>true</node_value>\n     </node>\n    <node>\n     <node_key>species</node_key>\n      <node>\n       <node_key>epitheton: </node_key><node_value>verucosa</node_value>\n      </node>\n    </node>\n   </node>\n  </scientific_name>\n  <scientific_name>\n   <node>\n    <node_key>scientificName</node_key>\n     <node>\n      <node_key>canonical: </node_key><node_value>Homo sapiens</node_value>\n     </node>\n     <node>\n      <node_key>verbatim: </node_key><node_value>Homo sapiens</node_value>\n     </node>\n     <node>\n      <node_key>normalized: </node_key><node_value>Homo sapiens</node_value>\n     </node>\n    <node>\n     <node_key>genus</node_key>\n      <node>\n       <node_key>epitheton: </node_key><node_value>Homo</node_value>\n      </node>\n    </node>\n     <node>\n      <node_key>parsed: </node_key><node_value>true</node_value>\n     </node>\n    <node>\n     <node_key>species</node_key>\n      <node>\n       <node_key>epitheton: </node_key><node_value>sapiens</node_value>\n      </node>\n    </node>\n   </node>\n  </scientific_name>\n</scientific_names>\n"
    r = @parser.parse_names_list("Betula verucosa\nHomo sapiens",'yaml')
    r.should == "--- \n- scientificName: \n    canonical: Betula verucosa\n    verbatim: Betula verucosa\n    normalized: Betula verucosa\n    genus: \n      epitheton: Betula\n    parsed: true\n    species: \n      epitheton: verucosa\n- scientificName: \n    canonical: Homo sapiens\n    verbatim: Homo sapiens\n    normalized: Homo sapiens\n    genus: \n      epitheton: Homo\n    parsed: true\n    species: \n      epitheton: sapiens\n"
  end
end