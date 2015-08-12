require 'spec_helper'
include ApiHelper

describe 'name_resolvers API' do

  before(:all) do
    FileUtils.rm(Dir.glob(Rails.root.join('tmp', 'name_resolvers', '*data')))
    FileUtils.rm(Dir.glob(Rails.root.join('tmp', 'name_resolvers', '*result')))
  end

  it 'should be able to use GET for resolving names' do
    get('/name_resolvers.json',
        names: 'Leiothrix argentauris (Hodgson, 1838)|' +
               'Treron|Larus occidentalis wymani|' +
               'Plantago major L.',
        data_source_ids: '1|3')
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:data].first[:results].first[:taxon_id].should == '6868221'
  end

  it 'should not contain id field if user did not supply id' do
    get('/name_resolvers.json',
        names: 'Leiothrix argentauris (Hodgson, 1838)|' +
               'Treron|Larus occidentalis wymani|Plantago major L.',
        data_source_ids: '1|3')
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:data].select { |r| r.has_key?(:id) }.size.should == 0
  end

  it 'github #6: should be able to use GET for only uninomials' do
    get('/name_resolvers.json',
        names: 'Rhizoclonium',
        data_source_ids: '1|3')
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res.size.should > 0
  end

  it 'should parse options correctly' do
    get('/name_resolvers.json',
        names: 'Leiothrix argentauris (Hodgson, 1838)|' +
        'Treron|Larus occidentalis wymani|Plantago major L.',
        data_source_ids: '1|3',
        with_context: false)
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:parameters][:with_context].should == false
  end

  it 'should be able to use POST for resolving names' do
    post('/name_resolvers.json',
        data: "1|Leiothrix argentauris (Hodgson, 1838)\n" +
              "2|Treron\n" +
              "3|Larus occidentalis wymani\n" +
              "4|Plantago major L.",
        data_source_ids: '1|3')
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:data].first[:results].first[:taxon_id].should == '6868221'
    res[:data].select { |r| r.has_key?(:supplied_id) }.size.should > 0
  end

  it 'expand search with resolve_once option set to false' do
    post('/name_resolvers.json',
        data: "2|Calidris cooperi\n" +
              "1|Leiothrix argentauris\n" +
              "4|Plantago major L.",
        data_source_ids: '1|3',
        resolve_once: true)
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:data][1][:results].size.should == 1
    res[:data][1][:results][0][:name_string].should == 'Leiothrix argentauris'
    post("/name_resolvers.json",
        data: "2|Calidris cooperi\n" +
              "1|Leiothrix argentauris\n" +
              "4|Plantago major L.",
        data_source_ids: '1|3',
        resolve_once: false)
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:data][1][:results].size.should == 3
    res[:data][1][:results].map {|r| r[:data_source_id]}.should == [1,1,3]
  end

  it 'should be able to find partial binomial and partial uninomial forms' do
    post('/name_resolvers.json',
        data: "2|Calidris cooperi alba\n" +
              "1|Liothrix argentauris something something\n" +
              "4|Plantago major L.\n5|Treron something",
        resolve_once: false)
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:data][-1].should == {
      supplied_name_string: 'Treron something',
      is_known_name: false,
      supplied_id: '5',
      results: [{
        data_source_id: 1,
        data_source_title: 'Catalogue of Life',
        gni_uuid: 'b85f8a2a-de4c-5ba0-bb94-2b4b8789ef08',
        name_string: 'Treron',
        canonical_form: 'Treron',
        classification_path:
          'Animalia|Chordata|Aves|Columbiformes|Columbidae|Treron',
        classification_path_ranks: nil,
        classification_path_ids:
          '2362377|2362754|2363138|2363188|2363295|2378348',
        taxon_id: '2378348',
        edit_distance: 0,
        match_type: 6,
        prescore: '1|0|0',
        score: 0.75}]
    }
    res[:data][-3][:supplied_name_string].should ==
      'Liothrix argentauris something something'
    res[:data][-3][:results].
      map {|r| [r[:match_type], r[:score]]}.
      should == [[5, 0.75], [5, 0.75], [5, 0.75]]
  end

  it 'should create default options' do
    data =  '2|Calidris cooperi\n1|Leiothrix argentauris\n4|Plantago major L.'
    post('/name_resolvers.json',
         data: data,
         preferred_data_sources: "3|1"
        )
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:parameters].should == { with_context: false,
                                 header_only: false,
                                 best_match_only: false,
                                 data_sources: [],
                                 preferred_data_sources: [3, 1],
                                 resolve_once: false }
  end

  it 'should be able to use uploaded file for resolving names' do
    file_test_names = File.join(File.dirname(__FILE__),
                                '..',
                                'files',
                                'bird_names.txt')
    file = Rack::Test::UploadedFile.new(file_test_names, 'text/plain')
    post('/name_resolvers.json',
         file: file,
         data_source_ids: '1|2')
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:data][1][:results].first[:taxon_id].should == '2433879'
  end

  it 'should be able to display only header' do
    get("/name_resolvers.json",
        names: 'Calidris cf. cooperi|Liothrix argentauris ssp.|' +
               'Treron aff. argentauris (Hodgson, 1838)|' +
               'Treron spp.|Calidris cf. cooperi',
        resolve_once: false,
        header_only: true)
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:data].should be_nil
    get("/name_resolvers.json",
        names: 'Calidris cf. cooperi|Liothrix argentauris ssp.|' +
               'Treron aff. argentauris (Hodgson, 1838)|' +
               'Treron spp.|Calidris cf. cooperi',
        resolve_once: false,
        header_only: false)
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:data].should_not be_nil
   end

  it 'should search whole GNI if there is no data source information' do
    get('/name_resolvers.json',
        names: 'Calidris cooperi|Liothrix argentauris|' +
               'Leiothrix argentauris (Hodgson, 1838)|' +
               'Treron|Larus occidentalis wymani|Plantago major L.',
        with_context: false,
        resolve_once: false)
    body = last_response.body

    res = JSON.parse(body, symbolize_names: true)
    res[:data][0][:results].first.should == {
      data_source_id: 2,
      data_source_title: nil,
      edit_distance: 0,
      gni_uuid: '6bfd9d6f-9c68-5f5a-bbc6-99759c730a84',
      name_string: 'Calidris cooperi',
      canonical_form: 'Calidris cooperi',
      classification_path: nil,
      classification_path_ranks: nil,
      classification_path_ids: nil,
      taxon_id: '5679',
      match_type: 1,
      prescore: '3|0|0',
      score: 0.988
    }
    res[:data][1][:results].first.should == {
      data_source_id: 1,
      data_source_title: 'Catalogue of Life',
      edit_distance: 1,
      gni_uuid: '4f273f15-8b8f-5412-9a02-b256585d8991',
      name_string: 'Leiothrix argentauris (Hodgson, 1838)',
      canonical_form: 'Leiothrix argentauris',
      classification_path: 'Animalia|Chordata|Aves|' +
                           'Passeriformes|Sylviidae|Leiothrix|' +
                           'Leiothrix argentauris',
      classification_path_ranks: nil,
      classification_path_ids: '2362377|2362754|2363138|' +
                               '2363139|2363166|2417185|6868221',
      taxon_id: '6868221',
      match_type: 3,
      prescore: '1|0|0',
      score: 0.75
    }
  end

  it 'should be able to return best match only' do
    Gni::Config.curated_data_sources = [1,2,3,4,5]
    get("/name_resolvers.json",
        names: 'Calidris cf. cooperi|Liothrix argentauris ssp.|' +
               'Treron aff. argentauris (Hodgson, 1838)|' +
               'Treron spp.|Calidris cf. cooperi',
        best_match_only: true,
        resolve_once: false)
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:parameters].should == { with_context: false,
                                 header_only: false,
                                 best_match_only: true,
                                 data_sources: [],
                                 preferred_data_sources: [],
                                 resolve_once: false }
    res[:data].map { |d| d[:results].size }.should == [1, 1, 1, 1, 1]
    get("/name_resolvers.json",
        names: 'Calidris cf. cooperi|Liothrix argentauris ssp.|' +
               'Treron aff. argentauris (Hodgson, 1838)|' +
               'Treron spp.|Calidris cf. cooperi',
        best_match_only: true,
        preferred_data_sources: '1',
        resolve_once: false)
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:parameters].should == { with_context: false,
                                 header_only: false,
                                 best_match_only: true,
                                 data_sources: [],
                                 preferred_data_sources: [1],
                                 resolve_once: false }
    res[:data].map { |d| d[:results].size }.should == [1, 1, 1, 1, 1]
    res[:data].map { |d| d[:preferred_results].size }.should == [0, 1, 1, 1, 0]
  end

  it 'should be able to find sp. epithets, with cf or aff qualifiers' do
    get("/name_resolvers.json",
        names: 'Calidris cf. cooperi|Liothrix argentauris ssp.|' +
               'Treron aff. argentauris (Hodgson, 1838)|' +
               'Treron spp.|Calidris cf. cooperi',
        resolve_once: false)
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res0 = res[:data][0]
    res0[:supplied_name_string].should == 'Calidris cf. cooperi'
    res0[:results].map {|r| r[:name_string]}.
      uniq.should == ['Calidris cooperi', 'Calidris cooperi (Baird, 1858)']
    res1 = res[:data][1]
    res1[:supplied_name_string].should == 'Liothrix argentauris ssp.'
    res1[:results].map {|r| r[:name_string]}.
      should == ["Leiothrix argentauris (Hodgson, 1838)",
                 "Leiothrix argentauris",
                 "Leiothrix argentauris (Hodgson, 1838)"]
    res2 = res[:data][2]
    res2[:supplied_name_string].should ==
      'Treron aff. argentauris (Hodgson, 1838)'
    res2[:results].map {|r| r[:name_string]}.uniq.should == ['Treron']
    res3 = res[:data][3]
    res3[:supplied_name_string].should == 'Treron spp.'
    res3[:results].map {|r| r[:name_string]}.uniq.should == ['Treron']
    res4 = res[:data][4]
    res4[:supplied_name_string].should == 'Calidris cf. cooperi'
    res4[:results].map { |r| r[:name_string] }.uniq.should ==
      ['Calidris cooperi', 'Calidris cooperi (Baird, 1858)']
  end

  it 'should produce an error if there are no names' do
    get('/name_resolvers.json',
        :names => '',
        :data_source_ids => '1|3',
        :with_context => false)
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:status].should == ProgressStatus.failed.name
    res[:message].should == NameResolver::MESSAGES[:no_names]
  end

  it 'should produce an error if there are too many names and make sure GET is executed without que' do
    get("/name_resolvers.json",
      names: (NameResolver::MAX_NAME_STRING + 1).
        times.inject([]) { |res| res << 'Plantago major'; res }.join('|'),
        :data_source_ids => "1")
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:status].should == ProgressStatus.failed.name
    res[:message].should == NameResolver::MESSAGES[:too_many_names]
  end

  it 'should return 404 for nonexisting results' do
    -> { get('/name_resolvers/12345_no_such_page.json') }.
      should raise_error(ActionController::RoutingError)
    -> { get('/name_resolvers') }.
      should_not raise_error(ActionController::RoutingError)
  end

  it "takes option with_vernaculars" do
    get("/name_resolvers.json",
        names: "Leiothrix argentauris (Hodgson, 1838)|" +
        "Treron|Larus occidentalis wymani|Plantago major L.",
        with_vernaculars: true)
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:parameters][:with_vernaculars].should == true
  end

  it "returns vernacular names" do
    get("/name_resolvers.json",
        names: "Actenoides bougainvillei (Rothschild, 1904)|"\
        "Chloroceryle amazona (Latham, 1790)|"\
        "Merops viridis Linnaeus, 1758",
        with_vernaculars: true)
    body = last_response.body
    res = JSON.parse(body, symbolize_names: true)
    res[:data].last[:results].last[:vernaculars].should == [{:name=>"Blue-throated Bee-eater", :language=>"English", :locality=>nil, :country_code=>nil}]
  end
end
