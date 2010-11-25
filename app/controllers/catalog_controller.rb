require 'gdata'
require 'nokogiri'
require 'open-uri'

class CatalogController < ApplicationController

  include OrderedQueryFacetingParametersHelper
  include Blacklight::SolrHelper
  
  before_filter :delete_or_assign_orderly_search_session_params,  :only=>:index

  # Incorporate code for call Google book search API up to 4 times to retrieve book covers using a
  # list of isbn numbers obtained from Solr.
  #
  # Multiple calls to Google are required because the Books Search API returns 0 hits if the request
  # contains more than 3 or 4 isbn numbers.
  #
  # Only for prototyping and usability testing purposes as multiple Google calls per search incurs
  # significance performance issues.
  def index

    extra_head_content << '<link rel="alternate" type="application/rss+xml" title="RSS for results" href="'+ url_for(params.merge("format" => "rss")) + '">'
    extra_head_content << '<link rel="alternate" type="application/atom+xml" title="Atom for results" href="'+ url_for(params.merge("format" => "atom")) + '">'

    (@response, @document_list) = get_search_results
    @filters = params[:f] || []

    if Blacklight.config[:data_augmentation][:enabled] and !(params[:q].blank? and params[:f].blank? and params[:search_field].blank?)
      get_gdata_for_result_list
    end

    respond_to do |format|
      format.html { save_current_search_params }
      format.mobile { save_current_search_params }
      format.rss  { render :layout => false }
      format.atom { render :layout => false }
    end
  end

  def show
    @response, @document = get_solr_response_for_doc_id
    
    if Blacklight.config[:data_augmentation][:enabled] 
      get_gdata_eulholding_details if @document[:isbn_t]
      @text_for_zemanta =  @gdata_description ?  @document[:opensearch_display].join(" ") + @gdata_description.text : @document[:opensearch_display].join(" ")
      create_zemanta_suggestions @text_for_zemanta if !is_device?("iphone")
    end

    respond_to do |format|
      format.html {setup_next_and_previous_documents}
      format.mobile { setup_next_and_previous_documents }
      # Add all dynamically added (such as by document extensions)
      # export formats.
      @document.export_formats.each_key do | format_name |
        # It's important that the argument to send be a symbol;
        # if it's a string, it makes Rails unhappy for unclear reasons.
        format.send(format_name.to_sym) { render :text => @document.export_as(format_name) }
      end
    end
  end
  
  def facet_list_limit
    if params[:id].include? "pub_date" 
      170
    else 
      80
    end
  end
  
  def facet
    if !params.has_key?("catalog_facet.sort") and (params[:id].include? "pub_date" or params[:id].include? "format" or params[:id].include? "mimetype_facet")
       params.merge!({:"catalog_facet.sort"=>"index"})
    elsif !params.has_key?("catalog_facet.sort") and (params[:id].include? "author_facet" or params[:id].include? "subject_topic_facet")
      params.merge!({:"catalog_facet.sort"=>"index"}) # a-z sort for the time being
    end
    @pagination = get_facet_pagination(params[:id], params)
  end
  
  # Blacklight solr_helper method override for a,b,..z alphabetic
  # range faceting navigation, to contruct the appropriate
  # solr_params to retrieve the additional a-z facets (if)
  def solr_facet_params(facet_field, extra_controller_params={})
    input = params.deep_merge(extra_controller_params)
    solr_params = solr_search_params(extra_controller_params)
    
    # add additional facet.field parameter to retrieve any a-z facets
    # e.g. solr_params[:"facet.field"] = [author_facet, "author_first_letter"]
    if Blacklight.config[:facet][:a_to_z].has_key? facet_field
      solr_params[:"facet.field"] = [facet_field, Blacklight.config[:facet][:a_to_z][facet_field]] 
    else
      solr_params[:"facet.field"] = facet_field
    end
    
    solr_params[:"f.#{facet_field}.facet.limit"] = 
      if solr_params["facet.limit"] 
        solr_params["facet.limit"] + 1
      elsif respond_to?(:facet_list_limit)
        facet_list_limit.to_s.to_i + 1
      else
        20 + 1
      end
    # use facet.prefix to filter out outliers not corresponding a particular alphabet facet
    solr_params['facet.prefix'] = extra_controller_params[:"catalog_facet.prefix"].upcase if extra_controller_params.has_key?("catalog_facet.prefix") 
    solr_params['facet.offset'] = input[  Blacklight::Solr::FacetPaginator.request_keys[:offset]  ].to_i
    solr_params['facet.sort'] = input[  Blacklight::Solr::FacetPaginator.request_keys[:sort] ]     
    solr_params[:rows] = 0
    
    return solr_params
  end
  
  # Blacklight solr_helper method override for a,b,..z alphabetic
  # range faceting navigation, to contruct either a facet 
  # paginator or a hash consisting two facet paginators 
  # (the intended facets + the a-z facets)
  def get_facet_pagination(facet_field, extra_controller_params={})
    solr_params = solr_facet_params(facet_field, extra_controller_params)
    response = Blacklight.solr.find(solr_params)

    limit =       
      if respond_to?(:facet_list_limit)
        facet_list_limit.to_s.to_i
      elsif solr_params[:"f.#{facet_field}.facet.limit"]
        solr_params[:"f.#{facet_field}.facet.limit"] - 1
      else
        nil
      end
      
    intended_facets = response.facets.select {|facet| facet.name.include?(facet_field)}.first.items
    intended_paginator = Blacklight::Solr::FacetPaginator.new(intended_facets, 
        :prefix => solr_params['facet.prefix'],
        :offset => solr_params['facet.offset'],
        :limit => limit,
        :sort => response["responseHeader"]["params"]["f.#{facet_field}.facet.sort"] || response["responseHeader"]["params"]["facet.sort"]
    )

    if Blacklight.config[:facet][:a_to_z].has_key? facet_field
      extra_controller_params.delete(Blacklight.config[:facet][:a_to_z][facet_field])
      prefix = extra_controller_params["catalog_facet.prefix"]
      extra_controller_params.delete("catalog_facet.prefix") # in order to retrieve the a-z facet listing
      extra_controller_params["catalog_facet.offset"]=0
      extra_controller_params["catalog_facet.sort"]= "index"
      solr_params = solr_facet_params(facet_field, extra_controller_params)
      response = Blacklight.solr.find(solr_params)
      a_to_z_facets = response.facets.select {|facet| facet.name.include?(Blacklight.config[:facet][:a_to_z][facet_field])}.first.items
      a_to_z_paginator =  Blacklight::Solr::FacetPaginator.new(a_to_z_facets,
        :prefix => prefix,
        :offset => solr_params['facet.offset'],
        :limit => limit,
        :sort => response["responseHeader"]["params"]["f.#{facet_field}.facet.sort"] || response["responseHeader"]["params"]["facet.sort"]
      )
      return { facet_field => intended_paginator, Blacklight.config[:facet][:a_to_z][facet_field] => a_to_z_paginator }
    else
      return intended_paginator
    end
   
  end

  protected

  # remember URL params (ordered) in session for URL reconstruction later
  def delete_or_assign_orderly_search_session_params
    session[:orderly_search_params] = {}
    # params_for_ui encodes URL query and faceting parameters)
    # in an orderly Dictionary Hash.
    params_for_ui.each_pair do |key, value|
      session[:orderly_search_params][key] = value
    end
  end

  def setup_next_and_previous_documents
    setup_previous_document
    setup_next_document
    render :layout => "layouts/item"
  end

  def create_zemanta_suggestions(text_for_suggestions)
    zemanta_suggestions_xml = Net::HTTP.post_form(URI.parse(Blacklight.config[:data_augmentation][:zemanta][:endpoint]),
                              { 'method'=>'zemanta.suggest', 'api_key'=> Blacklight.config[:data_augmentation][:zemanta][:developer_key],
                                'text'=> text_for_suggestions, 'format' => 'xml', 'return_images' => '0'})

    zemanta_suggestions =  Nokogiri::XML(zemanta_suggestions_xml.body)
    link_types = zemanta_suggestions.xpath("//markup/links/link/target/type")
    zemanta_link_types = link_types.collect { |link_type| link_type.text } if !link_types.empty?
    @zemanta_unique_link_types = zemanta_link_types.uniq.flatten.sort {|x,y| y <=> x } if zemanta_link_types
    @zemanta_links = zemanta_suggestions.xpath("//markup/links/link")
    @zemanta_articles = zemanta_suggestions.xpath("//articles/article")
  end

  def parse_voyager_holding_details(holding_details)
    holding_details.xpath('//tr').collect { |node|
      if !node.xpath('th/a').empty? and node.xpath('th/a').text=='Location (click for local info)'
        {
          :location => node.xpath('normalize-space(td)').gsub("STANDARD LOAN", "Standard Loan").gsub("SHORT LOAN", "Short Loan"),
          :shelfmark => node.xpath('following-sibling::tr[th ="Shelfmark:"][1]/td').text.strip!,
          :status => node.xpath('following-sibling::tr[th ="Status:"][1]/td').text.strip!.gsub("(Not Charged)","").downcase,
          :copies => node.xpath('following-sibling::tr[th ="Number of Items:"][1]/td').text.strip!
        }
      end
    }.compact
  end

  def get_gdata_for_result_list
    gdata_client = GData::Client::BookSearch.new
    isbn_nos = @response.docs.select {|x| x["isbn_t"] }.collect {|x| x["isbn_t"][0]}
    increments = 3

    3.times { |t|
      start_index = t*increments
      end_index = t*increments + 2
      if end_index > isbn_nos.size
        break if start_index > isbn_nos.size
        query_string = isbn_nos[start_index..-1].join("+OR+")
        gdata_xml = gdata_client.get(Blacklight.config[:data_augmentation][:gdata][:endpoint_book_search] + '?q=' + query_string).to_xml
        gdata = REXML::XPath.each(gdata_xml, "//entry").collect { |entry|
          isbn_node = entry.get_elements("dc:identifier[contains(.,'ISBN')]").first
          embeddability_node = entry.get_elements("gbs:embeddability").first
          [entry.get_elements("link").first.attribute("href").to_s, isbn_node ? isbn_node.text : "",  embeddability_node.attribute("value").to_s]
        }
        @gdata = @gdata.nil? ? gdata : @gdata + gdata # merge results to the calls
        break
      else
        query_string = isbn_nos[start_index..end_index].join("+OR+")
        gdata_xml = gdata_client.get(Blacklight.config[:data_augmentation][:gdata][:endpoint_book_search] + '?q=' + query_string).to_xml
        gdata = REXML::XPath.each(gdata_xml, "//entry").collect { |entry|
          isbn_node = entry.get_elements("dc:identifier[contains(.,'ISBN')]").first
          embeddability_node = entry.get_elements("gbs:embeddability").first
          [entry.get_elements("link").first.attribute("href").to_s, isbn_node ? isbn_node.text : "", embeddability_node.attribute("value").to_s]
        }
        @gdata = @gdata.nil? ? gdata : @gdata + gdata  # merge results to the calls
      end
    }
  end
  
  def get_gdata_eulholding_details
    gdata_client = GData::Client::BookSearch.new
    doc = gdata_client.get(Blacklight.config[:data_augmentation][:gdata][:endpoint_book_search] + '?q=' + @document[:isbn_t].last).to_xml
    gdata_url_id = REXML::XPath.first(doc, "//entry/id")
    if gdata_url_id
      gdata_id = gdata_url_id.text.split("/feeds/volumes/").last
      gdata_doc = gdata_client.get(Blacklight.config[:data_augmentation][:gdata][:endpoint_book_search] + '/' + gdata_id).to_xml
      @isbn = @document[:isbn_t].last
      @gdata_info_url =  REXML::XPath.first(gdata_doc, "//entry/link[@rel='http://schemas.google.com/books/2008/info']/@href")
      @gdata_image = REXML::XPath.first(gdata_doc, "//entry/link/@href")
      @gdata_description = REXML::XPath.first(gdata_doc, "//entry/dc:description")
      @gdata_embeddability = REXML::XPath.first(gdata_doc, "//entry/gbs:embeddability")
      @gdata_viewability = REXML::XPath.first(gdata_doc, "//entry/gbs:viewability")
    end
    #@eulholding = parse_voyager_holding_details Nokogiri::HTML(open('http://catalogue.lib.ed.ac.uk/cgi-bin/Pwebrecon.cgi?DB=local&Search_Arg=isbn+'+@document[:isbn_t].last+'&Search_Code=CMD&CNT=25'))
  end

end