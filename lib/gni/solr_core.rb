module Gni
  class SolrIngest
    # @queue = :solr_ingest

    # def self.perform(solr_injest_id, solr_url = Gni::Config.solr_url)
    #   classification = SolrIk.first(:id => classification_id)    
    #   raise RuntimeError, "No classification with id #{classification_id}" unless classification
    #   si = SolrIngest.new(classification, solr_url)
    #   si.ingest
    # end

    def initialize(core)
      @core = core
      @solr_client = SolrClient.new(solr_url: core.solr_url, update_csv_params: core.update_csv_params)
      @temp_file = "solr_" + @core.name + "_"
    end

    def ingest
      id_start = 0
      id_end = id_start + Gni::Config.batch_size
      while true
        rows = @core.get_rows(id_start, id_end)
        break if rows.blank?
        @csv_file_name = File.join(Gni::Config.temp_dir, (@temp_file + "%s_%s" % [id_start, id_end]))
        csv_file = create_csv_file
        rows.each do |row|
          csv_file << row
        end
        csv_file.close
        @solr_client.delete("name_string_id:[%s TO %s]" % [id_start, id_end])
        @solr_client.update_with_csv(@csv_file_name)
        FileUtils.rm(@csv_file_name)
        id_start = id_end
        id_end += Gni::Config.batch_size
      end
    end
    
    private
    
    def create_csv_file
      csv_file = CSV.open(@csv_file_name, "w:utf-8")
      csv_file << @core.fields
      csv_file
    end

  end

  class SolrCoreCanonicalForm
    attr :update_csv_params, :fields, :name, :solr_url

    def initialize
      @atomizer = Taxamatch::Atomizer.new
      @name = "canonical_forms"
      @solr_url = Gni::Config.solr_url + "/canonical_forms"
      @fields = %w(name_string_id canonical_form_id name_string canonical_form uninomial_auth uninomial_yr genus_auth genus_yr species_auth species_yr infraspecies_auth infraspecies_yr)
      @update_csv_params = "&" + @fields[4..-1].map { |f| "f.%s.split=true" % f }.join("&")
    end

    def get_rows(id_start, id_end)
      q = "select ns.id as name_string_id, cf.id as canonical_form_id, ns.name as name_string, cf.name as canonical_form, pns.data from name_strings ns join parsed_name_strings pns on pns.id=ns.id join canonical_forms cf on cf.id = ns.canonical_form_id where ns.canonical_form_id is not null and ns.id > %s and ns.id <= %s" % [id_start, id_end]
      rows = NameString.connection.select_rows(q)
      rows.each do |row|
        data = JSON.parse(row.pop, :symbolize_names => true)[:scientificName]
        next unless data[:details]
        res = @atomizer.organize_results(data)
        uninomial_auth = res[:uninomial] ? res[:uninomial][:normalized_authors] : []
        uninomial_years = res[:uninomial] ? res[:uninomial][:years] : []
        genus_auth = res[:genus] ? res[:genus][:normalized_authors] : []
        genus_years = res[:genus] ? res[:genus][:years] : []
        species_auth = res[:species] ? res[:species][:normalized_authors] : []
        species_years = res[:species] ? res[:species][:years] : []
        infraspecies_auth = res[:infraspecies] ? res[:infraspecies][0][:normalized_authors] : []
        infraspecies_years = res[:infraspecies] ? res[:infraspecies][0][:years] : []
        [uninomial_auth, uninomial_years, genus_auth, genus_years, species_auth, species_years, infraspecies_auth, infraspecies_years].each do |var|
          row << var.join(",")
        end
      end
      rows
    end
  end
end




__END__

  defingest
      @dwca = DarwinCore.new(@classification.file_path)
      data = @dwca.normalize_classification
      @solr_client.delete("classification_id:#{@classification.id}")
      delete_solr_csv_files
      organize_data(data) do |solr_data, i|
        csv_file = create_solr_csv_file(solr_data, i)
        @solr_client.update_with_csv(csv_file)
      end
    end

    private
    def create_solr_csv_file(solr_data, i)
      csv_file = File.join(TEMP_DIR, "#{@temp_file}#{i}")
      f = open(csv_file, 'w')
      f.write("classification_id,classification_uuid,taxon_id,taxon_classification_id,path,rank,current_scientific_name,current_scientific_name_exact,scientific_name_synonym,scientific_name_synonym_exact,common_name\n")
      solr_data.each do |r|
        row = [@classification.id]
        row << @classification.uuid
        row << csv_field(r[:taxon_id])
        row << csv_field([@classification.id, r[:taxon_id]].join("_")) 
        row << csv_field(r[:path].join('|'))
        row << csv_field(r[:rank])
        row << csv_field(r[:current_scientific_name])
        row << csv_field(r[:current_scientific_name_exact])
        synonyms = []
        synonym_canonicals = []
        common_names = []
        r[:scientific_name_synonyms].each do |name, canonical|
          synonyms << csv_field(name, false)
          synonym_canonicals << canonical
        end
        r[:common_names].each do |name|
          common_names << csv_field(name, false)
        end
        row << '"' + synonyms.join(',') + '"'
        row << '"' + synonym_canonicals.join(',') + '"'
        row << '"' + common_names.join(',') + '"'
        f.write(row.join(',') + "\n")
      end
      f.close
      csv_file
    end

    def delete_solr_csv_files
      Dir.entries(TEMP_DIR).select {|f| f.match /^#{@temp_file}/}.each {|f| FileUtils.rm(File.join(TEMP_DIR, f))}
    end

    def organize_data(data)
      res = []
      count = 0
      index = data.each do |key, value|
        count += 1
        taxon = {
          :taxon_id => key,
          :current_scientific_name => value.current_name,
          :current_scientific_name_exact => value.current_name_canonical,
          :scientific_name_synonyms => value.synonyms.map { |s| [s.name, s.canonical_name] },
          :common_names => value.vernacular_names.map { |v| v.name },
          :path => value.classification_path,
          :rank => value.rank,
        }
        res << taxon
        if count % ROWS_PER_FILE == 0
          # puts count.to_s + " records injested into solr"
          yield res, count
          res = []
        end
      end
      yield res, (count + 1)
    end

    def csv_field(a_string, add_quotes = true)
      return '' unless a_string
      if a_string.index(',')
        a_string.gsub!(/"/, '""')
        a_string = '"' + a_string + '"' if add_quotes
      end
      a_string
    end

        
  end
  
end