require 'vendor/plugins/blacklight/app/helpers/application_helper.rb'
require 'facets/dictionary'

# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  # Method overrides w.r.t Blacklight plugin application_helper-----------------------------------------------------
  
  # cf. Blacklight, add span to display the item hits differently
  def render_facet_value(facet_solr_field, item, options ={})
    facet_number_tag =  content_tag(:span, format_num(item.hits), :class => "facet_number")
    link_to_unless(options[:suppress_link], item.value, add_facet_params_and_redirect(facet_solr_field, item.value), :class=>"facet_select") + facet_number_tag
  end

  # cf. Blacklight, remove facet from Dictionary Hash which preserves URL parameters ordering
  # for both the breadcrumb trail and the faceting area
  # 'encoded_facet_name' is a unique facet key (appended with '_interaction_x') encoded in params_for_ui
  # 'x' is the current position (selection history) for a breadcrumb navigation (0...N)
  # e.g. p[:f] = {:subject_facet_interaction_0 => "physics",:subject_facet_interaction_1 => "maths" }
  def remove_facet_params(encoded_facet_name, value, localized_params=params)  
    p = localized_params.dup
    p[:f] = p[:f].dup
    p[:f].delete(encoded_facet_name) 
    # construct a request URL from the orderly Hash
    params_for_url (p[:q].empty? ? p[:f] :  p[:q].merge(p[:f]))
  end
  
  # cf. Blacklight, 'remove' link refers to the overriden remove_facet_params which
  # returns an orderly request string (based on Dictionary Hash)
  def render_selected_facet_value(facet_solr_field, item)
    unique_facet_field = params_for_ui[:f].select { |k,v| k.to_s.include?(facet_solr_field) and CGI::unescape(v)==item.value }[0][0]
    '<span class="selected">' +
    render_facet_value(facet_solr_field, item, :suppress_link => true) +
    '</span>' +
    ' [' + link_to("remove", catalog_index_path + remove_facet_params(unique_facet_field, item.value, params_for_ui), :class=>"remove") + ']'
  end
  
  # cf. Blacklight, add facet params to Dictionary Hash instead of Rails Hash 
  # to preserve the order of the key-value pairs in URL
  # also encodes the key for breadcrumb purposes
  def add_facet_params(field, value)
    p = params_for_ui
    p[:f]||= Dictionary.new
    encoded_facet_name = encode_facet_name_as_key(field, p[:f].size + 1)
    p[:f][encoded_facet_name.to_sym] = value
    p
  end

  # cf. Blacklight, add facet params to Dictionary Hash instead of Rails Hash 
  # to preserve the order of the key-value pairs in URL
  # render the Dictionary Hash in a request URI string according to 
  # faceting parameters order in the hash
  def add_facet_params_and_redirect(field, value)
    new_params = add_facet_params(field, value)

    # Delete page, if needed. 
    new_params.delete(:page)

    # Delete any request params from facet-specific action, needed
    # to redir to index action properly. 
    Blacklight::Solr::FacetPaginator.request_keys.values.each do |paginator_key| 
      new_params.delete(paginator_key)
    end
    new_params.delete(:id)

    # Force action to be index. 
    new_params[:action] = "index"
    params_for_url (new_params[:q].empty? ? new_params[:f] :  new_params[:q].merge(new_params[:f]))
  end
  
  # Method overrides w.r.t Blacklight plugin render_constraints_helper----------------------------------------------
  
  def render_constraints_query(localized_params = params)
    content = ""
    if (!localized_params[:q].blank?)
      localized_params[:q].each_pair do |query, value|
        if query.to_s.include?("q" + encoding_token)
          corresponding_search_field_key = ("search_field" + encoding_token +  index_from_encoded_key(query)).to_sym
          corresponding_search_field_value = localized_params[:q][corresponding_search_field_key]
          content << render_constraint_element(corresponding_search_field_value, decode_breadcrumb_key_for_name(value),
                  :classes => ["query"],
                  :remove => catalog_index_path(localized_params.merge(:q=>nil, :action=>'index')))
        end
      end
      return content
    end
  end

  # cf. Blacklight, instead of using Named Route + Hash rendering, 
  # :remove is constructed from the Dictionary Hash (with orderly parameters)
  # so that the rendered URL preserve the existing faceting (constraint) order 
  def render_constraints_filters(localized_params = params)
    return "" unless localized_params[:f]
    content = ""
    localized_params[:f].each_pair do |facet,values|        
      values.each do |val|
        content << render_constraint_element( facet_field_labels[decode_breadcrumb_key_for_name(facet)],
                val,
                :breadcrumb => catalog_index_path + create_breadcrumb_url(facet, val, localized_params),
                :remove => catalog_index_path + remove_facet_params(facet, val, localized_params),
                :classes => ["filter"] 
                ) + "\n"
      end
    end 
    return content    
  end
  
  # New helper methos w.r.t to Blacklight --------------------------------------------------------------------------
  
  # returns a Dictionary Hash (http://facets.rubyforge.org/apidoc/api/more/classes/Dictionary.html)
  # which preserve the order of query and facet key-value URL parameters.
  def params_for_ui
    {:q => order_encode_query_params, :f => order_encode_facet_params }
  end
  
  # construct a Dictionary Hash of faceting parameters from the request URL,
  # also encodes the facet name for breadcrumb navigation
  def order_encode_facet_params
    order_encode_parameters = Dictionary.new
    # split and extract facet parameters from the request uri (currently testing faceting only)
    facets_string_array = request.query_string.split('&').select { |i| i[0..0].include?("f")}
    facets_string_array.each_with_index { |f, index|
      # extract encode facet name (getting rids of "[","]" char from URL)
      encoded_facet_name = encode_facet_name_as_key(f.split('=')[0][1..-1].gsub(/%5D|%5B/,''), index)
      facet_value = f.split('=')[1]
      order_encode_parameters[encoded_facet_name.to_sym]= CGI::unescape(facet_value)
    }
    order_encode_parameters
  end
  
  # construct a Dictionary Hash of query parameters from the request URL,
  # also encodes the facet name for breadcrumb navigation
  def order_encode_query_params
    order_encode_parameters = Dictionary.new
    # split and extract facet parameters from the request uri (currently testing faceting only)
    query_string_array = request.query_string.split('&').select { |i| i[0..0].include?("q") or i.include?("search_field")}
    query_string_array.each_with_index { |f, index|
      index_no = f.split('=')[0].include?("search_field") ? index - 1 : index
      key = encode_query_name(f.split('=')[0], index_no)
      value = f.split('=')[1]
      order_encode_parameters[key.to_sym]= CGI::unescape(value)
    }
    order_encode_parameters
  end

  # given a Dictionary Hash with orderly query/faceting parameters (constraints)
  # construct a URL request string reflecting the order of the hash, e.g. 
  # from {:subject_facet_interaction_0 => "physics",:subject_facet_interaction_1 => "maths" }
  # to "?f[:subject_facet][]=physics&f[:subject_facet][]=maths"
  def params_for_url(localized_params=params)    
    url_queries = "?"
    localized_params.each { |item|
      key = decode_breadcrumb_key_for_name(item[0])
      if key.include?("q") or key.include?("search_field") 
        url_queries = url_queries + key +"="+item[1] + "&"
      else
        url_queries = url_queries + "f"+ CGI::escape("["+key+"][]")+"="+item[1] + "&"
      end
    }
    url_queries.chomp("&")
  end
  
  # e.g. encodes {:subject_facet => [physics, maths] } into
  # :subject_facet_interaction_0 => "physics",:subject_facet_interaction_1 => "maths"
  # for breadcrumbs navigation
  def encode_facet_name_as_key(facet_name,index)
    facet_name + encoding_token + index.to_s
  end
  
  # e.g. encodes {:subject_facet => [physics, maths] } into
  # :subject_facet_interaction_0 => "physics",:subject_facet_interaction_1 => "maths"
  # for breadcrumbs navigation
  def encode_query_name(query_name,index)
    query_name + encoding_token + index.to_s
  end

  # e.g. decodes :subject_facet_interaction_0 into :subject_facet
  def decode_breadcrumb_key_for_name(encoded_query_or_facet_key)
    encoded_query_or_facet_key.to_s.split(encoding_token)[0]
  end

  # token used to encode facet and query name with
  # interaction order (number) as per user interactions
  def encoding_token
     '_interaction_'
  end

  # e.g. gets '0' from ':subject_facet_interaction_0'
  def index_from_encoded_key(encoded_query_or_facet_key)
    encoded_query_or_facet_key.to_s.split(encoding_token)[1]
  end
  
  def create_breadcrumb_url(encoded_facet_name, value, localized_params=params)  
    current_position = breadcrumb_position encoded_facet_name
    p = localized_params.dup
    p[:f] = p[:f].dup.merge(p[:q])
    params_for_url p[:f].select { |k,v|  breadcrumb_position(k) <= current_position }
  end
  
  def breadcrumb_position(encoded_facet_name)
    encoded_facet_name.to_s.split(encoding_token)[1]
  end
  
end
