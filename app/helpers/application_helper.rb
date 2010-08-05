require 'vendor/plugins/blacklight/app/helpers/application_helper.rb'
require 'vendor/plugins/blacklight_advanced_search/app/helpers/application_helper.rb'
# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  #overrides 'render_facet_value' in Blacklight plugin helpe
  def render_facet_value(facet_solr_field, item, options ={})    
    link_to_unless(options[:suppress_link], item.value, add_facet_params_and_redirect(facet_solr_field, item.value), :class=>"facet_select") + content_tag(:span, format_num(item.hits), :class => "facet_number") 
  end
  
end
