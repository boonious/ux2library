require 'gdata'
require 'xmlsimple'

class CatalogController < ApplicationController

  include OrderedQueryFacetingParametersHelper
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

    if !(params[:q].blank? and params[:f].blank? and params[:search_field].blank?)
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

    respond_to do |format|
      format.html { save_current_search_params }
      format.rss  { render :layout => false }
      format.atom { render :layout => false }
    end
  end

  def show
    @response, @document = get_solr_response_for_doc_id

    if @document[:isbn_t]
      gdata_client = GData::Client::BookSearch.new
      doc = gdata_client.get(Blacklight.config[:data_augmentation][:gdata][:endpoint_book_search] + '?q=' + @document[:isbn_t].last).to_xml
      gdata_url_id = REXML::XPath.first(doc, "//entry/id")
      if gdata_url_id
        gdata_id = gdata_url_id.text.split("/feeds/volumes/").last
        gdata_doc = gdata_client.get(Blacklight.config[:data_augmentation][:gdata][:endpoint_book_search] + '/' + gdata_id).to_xml
        @gdata_image = REXML::XPath.first(gdata_doc, "//entry/link/@href")
        @gdata_description = REXML::XPath.first(gdata_doc, "//entry/dc:description")
        @gdata_embeddability = REXML::XPath.first(gdata_doc, "//entry/gbs:embeddability")
        @gdata_viewability = REXML::XPath.first(gdata_doc, "//entry/gbs:viewability")
      end
    end
     
    @text_for_zemanta =  @gdata_description ?  @document[:opensearch_display].join(" ") + @gdata_description.text : @document[:opensearch_display].join(" ")
    @zemanta_suggestions_test = Net::HTTP.post_form(URI.parse(Blacklight.config[:data_augmentation][:zemanta][:endpoint]),
                              { 'method'=>'zemanta.suggest', 'api_key'=> Blacklight.config[:data_augmentation][:zemanta][:developer_key],
                                'text'=> @text_for_zemanta, 'format' => 'xml', 'return_images' => '0'})
    
    @zemanta_suggestions = XmlSimple.xml_in(@zemanta_suggestions_test.body)
    links = @zemanta_suggestions["markup"][0]["links"][0]
    zemanta_link_type_array = @zemanta_suggestions["markup"][0]["links"][0]["link"].collect { |link| link["target"][0]["type"]} if !links.empty?
    @zemanta_link_types = zemanta_link_type_array.uniq.flatten.sort {|x,y| y <=> x } if zemanta_link_type_array
    @zemanta_articles = @zemanta_suggestions["articles"][0]

    respond_to do |format|
      format.html {setup_next_and_previous_documents}
      # Add all dynamically added (such as by document extensions)
      # export formats.
      @document.export_formats.each_key do | format_name |
        # It's important that the argument to send be a symbol;
        # if it's a string, it makes Rails unhappy for unclear reasons.
        format.send(format_name.to_sym) { render :text => @document.export_as(format_name) }
      end
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

end