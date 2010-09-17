require 'gdata'
require 'xmlsimple'

class CatalogController < ApplicationController
  
  # get single document from the solr index
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
  
end