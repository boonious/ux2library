require 'vendor/plugins/blacklight/app/helpers/application_helper.rb'
require 'vendor/plugins/blacklight_advanced_search/app/helpers/application_helper.rb'
require 'facets/dictionary'

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  # Method overrides w.r.t Blacklight plugin application_helper--------------------
  
  # cf. Blacklight, add span to display the item hits differently
  def render_facet_value(facet_solr_field, item, options ={})
    facet_number_tag =  content_tag(:span, format_num(item.hits), :class => "facet_number")
    link_to_unless(options[:suppress_link], item.value, add_facet_params_and_redirect(facet_solr_field, item.value), :class=>"facet_select") + facet_number_tag
  end
  
  
  # Method overrides w.r.t Blacklight plugin render_constraints_helper--------------------
  
  # placeholder method override, to prevent exception
  # currently 'remove_facet_params' doesn't work due to the use of Dictionary hash
  # - simple makes :remove call 'string'
  def render_constraints_filters(localized_params = params)
     return "" unless localized_params[:f]
     content = ""
     localized_params[:f].each_pair do |facet,values|
        values.each do |val|
           content << render_constraint_element( facet_field_labels[facet],
                  val, 
                  :remove => "catalog_index_path(remove_facet_params(facet, val, localized_params))",
                  :classes => ["filter"] 
                ) + "\n"                 					            
				end
     end 
     return content    
  end
  
  # New helper methos w.r.t to Blacklight ------------------
  
  # returns a Dictionary (http://facets.rubyforge.org/apidoc/api/more/classes/Dictionary.html) Hash 
  # which preserve the order of faceting key-value URL parameters. Note: currently testing faceting
  # navigation only
  def params_for_ui
    {:f => order_encode_facet_params }
  end
  
  # construct an orderly Dictionary Hash of faceting parameters from the request URL,
  # also encodes the facet name for breadcrumb trail
  def order_encode_facet_params
    order_encode_parameters = Dictionary.new
    # split and extract facet parameters from the request uri (currently testing faceting only)
    facets_string_array = request.query_string.split('&').select { |i| i[0..0].include?("f")}
    facets_string_array.each_with_index { |f, index|
      # extract encode facet name (getting rids of "[","]" char from URL)
      encoded_facet_name = encode_facet_name(f.split('=')[0][1..-1].gsub(/%5D|%5B/,''), index)
      facet_value = f.split('=')[1]
      order_encode_parameters[encoded_facet_name.to_sym]= CGI::unescape(facet_value)
    }
    order_encode_parameters
  end
  
  # e.g. encodes {:subject_facet => [physics, maths] } into
  # :subject_facet_interaction_0 => "physics",:subject_facet_interaction_1 => "maths"
  # for the purposes of breadcrumbs trails
  def encode_facet_name(facet_name,index)
    facet_name + "_interaction_" + index.to_s
  end
  
end
