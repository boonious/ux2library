# You can configure Blacklight from here. 
#   
#   Blacklight.configure(:environment) do |config| end
#   
# :shared (or leave it blank) is used by all environments. 
# You can override a shared key by using that key in a particular
# environment's configuration.
# 
# If you have no configuration beyond :shared for an environment, you
# do not need to call configure() for that envirnoment.
# 
# For specific environments:
# 
#   Blacklight.configure(:test) {}
#   Blacklight.configure(:development) {}
#   Blacklight.configure(:production) {}
# 

Blacklight.configure(:shared) do |config|

  # Set up and register the default SolrDocument Marc extension
  SolrDocument.extension_parameters[:marc_source_field] = :marc_display
  SolrDocument.extension_parameters[:marc_format_type] = :marc21
  SolrDocument.use_extension( Blacklight::Solr::Document::Marc) do |document|
    document.key?( :marc_display  )
  end
    
  # Semantic mappings of solr stored fields. Fields may be multi or
  # single valued. See Blacklight::Solr::Document::ExtendableClassMethods#field_semantics
  # and Blacklight::Solr::Document#to_semantic_values
  SolrDocument.field_semantics.merge!(    
    :title => "title_display",
    :author => "author_display",
    :language => "language_facet"  
  )
        
  
  ##############################

  config[:default_solr_params] = {
    :qt => "search",
    :per_page => 10 
  }
  
  
  

  # solr field values given special treatment in the show (single result) view
  config[:show] = {
    :html_title => "title_display",
    :heading => "title_display",
    :display_type => "format"
  }

  # solr fld values given special treatment in the index (search results) view
  config[:index] = {
    :show_link => "title_display",
    :record_display_type => "format"
  }

  # solr fields that will be treated as facets by the blacklight application
  #   The ordering of the field names is the order of the display
  # TODO: Reorganize facet data structures supplied in config to make simpler
  # for human reading/writing, kind of like search_fields. Eg,
  # config[:facet] << {:field_name => "format", :label => "Format", :limit => 10}
  config[:facet] = {
    :field_names => (facet_fields = [
      "library_facet",
      "format",
      "pub_date",
      "author_facet",
      "subject_topic_facet",
      "mimetype_facet",
      "language_facet",
     # "lc_1letter_facet",
     # "subject_geo_facet",
     # "subject_era_facet"
    ]),
    :labels => {
      "library_facet"       => "Library",
      "format"              => "Type",
      "pub_date"            => "Year",
      "author_facet"        => "Author",
      "subject_topic_facet" => "Topic",
      "mimetype_facet"      => "Technical Format",
      "language_facet"      => "Language",
     # "lc_1letter_facet"    => "Call Number",
     # "subject_era_facet"   => "Era",
     # "subject_geo_facet"   => "Region"
    },
    # Setting a limit will trigger Blacklight's 'more' facet values link.
    # If left unset, then all facet values returned by solr will be displayed.
    # nil key can be used for a default limit applying to all facets otherwise
    # unspecified. 
    # limit value is the actual number of items you want _displayed_,
    # #solr_search_params will do the "add one" itself, if neccesary.
    :limits => {
      nil => 10,
      "format"              => 10,
      "pub_date"            => 10,
      "author_facet"        => 10,
      "subject_topic_facet" => 10,
      "mimetype_facet"      => 10,
      "language_facet"      => 10,
      "author_first_letter" => 26,
      "subject_topic_first_letter" => 26,
    },
    :a_to_z => {
      :common_key_name  => "first_letter",
      "author_facet"    => "author_first_letter",
      "subject_topic_facet"    => "subject_topic_first_letter"
    }
  }

  # Have BL send all facet field names to Solr, which has been the default
  # previously. Simply remove these lines if you'd rather use Solr request
  # handler defaults, or have no facets.
  config[:default_solr_params] ||= {}
  config[:default_solr_params][:"facet.field"] = facet_fields

  # solr fields to be displayed in the index (search results) view
  #   The ordering of the field names is the order of the display 
  config[:index_fields] = {
    :field_names => [
      "title_display",
      "title_vern_display",
      "subtitle_display",
      "author_display",
      "author_vern_display",
      "format",
      "pub_date"
     # "language_facet",
     #  "published_display",
     # "published_vern_display",
     #  "lc_callnum_display"
    ],
    :labels => {
      "title_display"           => "Title:",
      "title_vern_display"      => "Title:",
      "subtitle_display"        => "Subtitle:",
      "author_display"          => "Author:",
      "author_vern_display"     => "Author:",
      "format"                  => "Format:",
      "pub_date"                => "Year:"
    #  "language_facet"          => "Language:",
    #  "published_display"       => "Published:",
    #  "published_vern_display"  => "Published:",
    #  "lc_callnum_display"      => "Call number:"
    }
  }

  # solr fields to be displayed in the show (single result) view
  #   The ordering of the field names is the order of the display 
  config[:show_fields] = {
    :field_names => [
      "title_display",
      "title_vern_display",
      "subtitle_display",
      "subtitle_vern_display",
      "author_display",
      "author_vern_display",
      "format",
      "url_fulltext_display",
      "url_suppl_display",
      "material_type_display",
      "language_facet",
      "published_display",
      "published_vern_display",
      "lc_callnum_display",
      "isbn_display",
      "subject_topic_facet"
    ],
    :labels => {
      "title_display"           => "Title:",
      "title_vern_display"      => "Title:",
      "subtitle_display"        => "Subtitle:",
      "subtitle_vern_display"   => "Subtitle:",
      "author_display"          => "Author:",
      "author_vern_display"     => "Author:",
      "format"                  => "Type:",
      "url_fulltext_display"    => "URL:",
      "url_suppl_display"       => "More Information:",
      "material_type_display"   => "Physical description:",
      "language_facet"          => "Language:",
      "published_display"       => "Published:",
      "published_vern_display"  => "Published:",
      "lc_callnum_display"      => "Call number:",
      "isbn_display"                  => "ISBN:",
      "subject_topic_facet"     => "Subject:"
    }
  }


  # "fielded" search configuration. Used by pulldown among other places.
  # For supported keys in hash, see rdoc for Blacklight::SearchFields
  # Note additional solr_parameters on a per-search-field basis can be given
  # with :solr_parameters and :solr_local_parameters (the latter for $param
  # solr LocalParams that can reference other params). 
  config[:search_fields] ||= []
  config[:search_fields] << {:key => "all_fields",  :display_label => 'All Fields', :qt => 'search'}
  config[:search_fields] << {:key => 'title', :qt => 'title_search'}
  config[:search_fields] << {:key =>'author', :qt => 'author_search'}
  config[:search_fields] << {:key => 'subject', :qt=> 'subject_search'}
  
  # "sort results by" select (pulldown)
  # label in pulldown is followed by the name of the SOLR field to sort by and
  # whether the sort is ascending or descending (it must be asc or desc
  # except in the relevancy case).
  # label is key, solr field is value
  config[:sort_fields] ||= []
  config[:sort_fields] << ['relevance', 'score desc, pub_date_sort desc, title_sort asc']
  config[:sort_fields] << ['year, recent', 'pub_date_sort desc, title_sort asc']
  config[:sort_fields] << ['year, older', 'pub_date_sort asc, title_sort asc']
  config[:sort_fields] << ['author', 'author_sort asc, title_sort asc']
  config[:sort_fields] << ['title', 'title_sort asc, pub_date_sort desc']
  
  # If there are more than this many search results, no spelling ("did you 
  # mean") suggestion is offered.
  config[:spell_max] = 5
  
  config[:data_augmentation] = {
    :enabled => true,
    :gdata => { 
      :endpoint_book_search => 'http://books.google.com/books/feeds/volumes'
    },
    :zemanta => {
      :endpoint => 'http://api.zemanta.com/services/rest/0.0/',
      :developer_key => 'c9e66y95zpx248rhng6r52ny'
    }
  }
end

