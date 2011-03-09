class BookmarksController < ApplicationController
  index.response do |wants|
    wants.html
    wants.mobile { render :layout => "item" }
  end
  edit.response do |wants|
    wants.html
    wants.mobile { render :layout => "refine" }
  end
  update.response do |wants|
    wants.html { redirect_to :action => "index" }
    wants.mobile { redirect_to :action => "index" }
  end
end
