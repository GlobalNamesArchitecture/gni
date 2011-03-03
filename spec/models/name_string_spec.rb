require File.dirname(__FILE__) + '/../spec_helper'

describe 'NameString.normalize_name_string' do
  it "should convert strings to normalized form" do
    strings = [
      ['Betula','Betula'], #no changes
      # ['Betula Mark&John', 'Betula Mark & John'], #one space before and after ampersand
      #  ['Parus major ( L. )', 'Parus major (L.)'],
      #  ['Parus major [ L . ]', 'Parus major [L.]'],
      #  ['Parus major (    L   .& Murray 188? )', 'Parus major (L. & Murray 188?)'],
      #  ["Plantago\t\t minor L. , Murray&Linn 1733", 'Plantago minor L., Murray & Linn 1733'],
      #  ['Plantago major : some garbage ,more of it', 'Plantago major: some garbage, more of it'],
      #  ["Parus minor\n\r L. 1774", 'Parus minor L. 1774'],
      #  ['Ceanothus divergens ssp. confusus (J. T. Howell) Abrams', 'Ceanothus divergens ssp. confusus (J. T. Howell) Abrams']
      ['Plantago     major     L.   ', 'Plantago major L.']
      ]
    strings.each do |ns|
      NameString.normalize_name_string(ns[0]).should == ns[1]
    end
  end
end


describe NameString do
  before :all do
    EolScenario.load :application
    EolScenario.load :name_string_search
    @data_source = DataSource.find(1)
    @user = User.find(1)
  end

  after :all do
    truncate_all_tables
  end

  #it { should have_one(:kingdom) }
  #it { should have_many(:name_indices) }

  it "should require a valid #name" do
    NameString.gen( :name => 'Plantago' ).should be_valid
    NameString.build( :name => 'Plantago' ).should_not be_valid # because there's already Plantago
  end

  it "should find names with * or %" do
    name_strings = NameString.search("adn%", nil, nil, 1, 10)
    name_strings.should_not be_nil
    name_strings.size.should > 0
    ns1_size = name_strings.size
    name_strings = NameString.search("adn*", nil, nil, 1, 10)
    name_strings.should_not be_nil
    name_strings.size.should == ns1_size
  end

  it "should find a name by canonical form" do
    name_strings = NameString.search("adnaria frondosa", nil, nil, 1, 10)
    name_strings.should_not be_nil
    name_strings.size.should == 1
    name_strings[0].name.should == 'Adnaria frondosa (L.) Kuntze'
  end

  it "should find the same resulrs with or without removed characters: ()[]|.,&;" do
    name_strings1 = NameString.search("frondosa adnaria ", nil, nil, 1, 10)
    name_strings2 = NameString.search("|frondosa,| & [(adnaria.)];", nil, nil, 1, 10)
    name_strings1.should_not be_nil
    name_strings2.should_not be_nil
    name_strings1.should == name_strings2
  end

  it "should find a name with any words sequence" do
    name_strings = NameString.search("frondosa adnaria", nil, nil, 1, 10)
    name_strings.should_not be_nil
    name_strings.size.should == 1
    name_strings[0].name.should == 'Adnaria frondosa (L.) Kuntze'
  end

  it "should_find name by partial canonical form" do
     name_strings = NameString.search("frondosa adn%", nil, nil, 1, 10)
     name_strings.should_not be_nil
     name_strings.size.should > 0
     name_strings[0].name.should == 'Adnaria frondosa (L.) Kuntze'
   end

   it "should find name with author" do
     search_term = "Adnaria frondosa (L.)"
     name_strings = NameString.search(search_term, nil, nil, 1, 10)
     name_strings.should_not be_nil
     name_strings.size.should > 0
     name_strings[0].name.should == 'Adnaria frondosa (L.) Kuntze'
   end

   it "should find a name by canonical form in a data_source" do
     name_strings = NameString.search("adnaria frondosa", @data_source.id, nil, 1, 10)
     name_strings.should_not be_nil
     name_strings.size.should > 0
     name_strings[0].name.should == 'Adnaria frondosa (L.) Kuntze'
   end

   it "should find a name by partial canonical form in a datasource" do
     name_strings = NameString.search("adn%", @data_source.id, nil, 1, 10)
     name_strings.should_not be_nil
     name_strings.size.should > 0
     name_strings[0].name.should == 'Adnaria frondosa (L.) Kuntze'
   end

   it "should find name with author in a datasource" do
     search_term = "Adnaria frondosa (L.)"
     name_strings = NameString.search(search_term, @data_source.id, nil, 1, 10)
     name_strings.should_not be_nil
     name_strings.size.should > 0
     name_strings[0].name.should == 'Adnaria frondosa (L.) Kuntze'
   end

   it "should not find name if it is not in a datasource" do
     search_term = "Adnaria frondosa (L.)"
     name_strings = NameString.search(search_term, 100, nil, 1, 10)
     name_strings.size.should == 0
   end

   it "should find a name in datasources belonging to a user" do
     name_strings = NameString.search("adnaria L", nil, @user.id, 1, 10)
     name_strings.should_not be_nil
     name_strings.size.should > 0
     name_strings[0].name.should == 'Adnaria frondosa (L.) Kuntze'
   end

   it "should find name with author in datasources belogning to a user" do
     search_term = "Adnaria frondosa (L.)"
     name_strings = NameString.search(search_term, nil, @user.id, 1, 10)
     name_strings.should_not be_nil
     name_strings.size.should > 0
     name_strings[0].name.should == 'Adnaria frondosa (L.) Kuntze'
   end

   it "should not find a name which does not belong to a user" do
     search_term = "Adnaria frondosa (L.)"
     name_strings = NameString.search(search_term, nil, 100, 1, 10)
     name_strings.should_not be_nil
     name_strings.size.should == 0
   end

   it "should find genera with gen: qualifier" do
    search_term = "gen:Hig%"
    name_strings = NameString.search(search_term, nil, nil, 1, 10)
    name_strings.should_not be_nil
    name_strings.size.should > 0
   end

  it "should work with several qualifiers" do
    search_term = "gen:Hig% sp:plum%"
    name_strings = NameString.search(search_term, nil, nil, 1, 10)
    name_strings.should_not be_nil
    name_strings.size.should > 0
  end

  it "should ignore wrong qulaifiers" do
    search_term = "gen:Hig% wrong:plum%"
    name_strings = NameString.search(search_term, nil, nil, 1, 10)
    name_strings.should_not be_nil
    name_strings.size.should == 0
  end

  it "should work with canonical form search" do
    search_term = "can:Higena plumigera"
    name_strings = NameString.search(search_term, nil, nil, 1, 10)
    name_strings.should_not be_nil
    name_strings.size.should == 5
    search_term = "can:Higena plumigera"
    name_strings = NameString.search(search_term, nil, nil, 1, 10)
    name_strings.should_not be_nil
    name_strings.size.should == 5
  end

  it "should work with exact name string search" do
    search_term = "exact:Adnaria frondosa (L.) Kuntze"
    name_strings = NameString.search(search_term, nil, nil, 1, 10)
    name_strings.should_not be_nil
    name_strings.size.should == 1
    name_strings[0].name.should == "Adnaria frondosa (L.) Kuntze"
    search_term = "exact:Adnaria frondosa (L.) Kuntz"
    name_strings = NameString.search(search_term, nil, nil, 1, 10)
    name_strings.should == []
  end

  it "should work with all qualifiers" do
    search_terms = ['can:Higena plumigera', 'yr:1787', 'sp:plumigera', 'gen:Adnatosphaeridium', 'uni:Higena', 'au:Williams au:G.', 'ssp:elegans']
    search_terms.each do |st|
      name_strings = NameString.search(st, nil, nil, 1, 10)
      name_strings.should_not be_nil
      name_strings.size.should > 0
    end
  end

  it "should be able to search names_strings as well" do
    search_terms = ["ns:Higena pl%", "yr:1787 ns:Hig%"]
    search_terms.each do |search_term|
      name_strings = NameString.search(search_term, nil, nil, 1, 10)
      name_strings.should_not be_nil
      name_strings.size.should > 0
    end
    search_terms = ["ns:Higena 1787", "ns:Hig% yr:1787"]
    search_terms.each do |search_term|
      name_strings = NameString.search(search_term, nil, nil, 1, 10)
      name_strings.should_not be_nil
      name_strings.size.should == 0
    end
  end

  it "words should be treated only with and" do
    search_term = "Ship* Plantago"
    name_strings = NameString.search(search_term, nil, nil, 1, 10)
    name_strings.should_not be_nil
    name_strings.size.should > 0
    name_strings.each do |ns|
      ns.name.match('Ship').should be_true
      ns.name.match('Plantago').should be_true
    end
  end

  it "should find namestring" do
    search_term = "ns:hig*"
    name_strings = NameString.search(search_term, nil, nil, 1, 10)
    name_strings.should_not be_nil
    name_strings.size.should > 0
  end

  it "should find id" do
    search_term = "id:17"
    name_strings = NameString.search(search_term, nil, nil, 1, 10)
    name_strings.should_not be_nil
    name_strings.size.should > 0
  end

  describe "UUID handling" do
    before(:all) do
      @name_string = NameString.last
    end

    it "should convert uuid to bytes" do
      NameString.uuid2bytes(@name_string.uuid_hex).should == UUID.parse("bcd01c45-ded8-59db-a913-a5a8a43b8a40").raw_bytes
    end

    it "#uuid_hex" do
      @name_string.uuid_hex.should == 'bcd01c45-ded8-59db-a913-a5a8a43b8a40'
    end

    it "#lsid" do
      @name_string.lsid.should == 'urn:lsid:globalnames.org:index:bcd01c45-ded8-59db-a913-a5a8a43b8a40'
    end

    it "should return bytes with #uuid" do
      @name_string.uuid.should == UUID.parse("bcd01c45-ded8-59db-a913-a5a8a43b8a40").raw_bytes
    end

  end

end

