require 'facets/dictionary'

module OrderedQueryFacetingParametersHelper
  
  # New helper methods w.r.t to Blacklight --------------------------------------------------------------------------
  
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
  
  # remove query from the Dictionary Hash which preserves URL parameters ordering
  # 'encoded_key' is a unique query key (appended with '_interaction_x') encoded in params_for_ui
  # 'x' is the current position (selection history) for a breadcrumb navigation (0...N)
  # 'x' is used for future purposes when multiple keyword searches will be accepted
   def remove_query_params(encoded_q_key, encoded_search_field_key, localized_params=params)
     p = localized_params.dup
     p[:q] = p[:q].dup
     p[:q].delete(encoded_q_key)
     p[:q].delete(encoded_search_field_key)
     # construct a request URL from the orderly Hash
     params_for_url (p[:f].empty? ? p[:q] :  p[:q].merge(p[:f]))
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
        url_queries = url_queries + "f"+ CGI::escape("["+key+"][]")+"="+item[1] + "&" unless key.include? Blacklight.config[:facet][:a_to_z][:common_key_name]
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
  
  def create_breadcrumb_url(encoded_key, value, localized_params=params)  
    current_position = breadcrumb_position encoded_key
    p = localized_params.dup
    if encoded_key.to_s.include?("q"+encoding_token)
      p[:q] = p[:q].dup
      previous_current_breadcrumbs = p[:q].select { |k,v|  breadcrumb_position(k) <= current_position }
      params_for_url (hash_from_breadcrumb_array previous_current_breadcrumbs).merge(p[:f])
    else
      p[:f] = p[:f].dup
      previous_current_breadcrumbs = p[:f].select { |k,v|  breadcrumb_position(k) <= current_position }
      params_for_url (hash_from_breadcrumb_array previous_current_breadcrumbs).merge(p[:q])
    end
  end

  def hash_from_breadcrumb_array(breadcrumb_array)
    breadcrumb_dictionary_hash = Dictionary.new
    breadcrumb_array.each { |item|
      breadcrumb_dictionary_hash[item[0]]=item[1]
    }
    breadcrumb_dictionary_hash
  end

  def breadcrumb_position(encoded_key)
    encoded_key.to_s.split(encoding_token)[1]
  end
  
end
