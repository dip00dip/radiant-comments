module CommentTags
  include Radiant::Taggable
  include WillPaginate::ViewHelpers
  
  class RadiantLinkRenderer < WillPaginate::LinkRenderer
    include ActionView::Helpers::TagHelper

    def initialize(tag)
      @tag = tag
    end
    
    def page_link(page, text, attributes = {})
      attributes = tag_options(attributes)
      @paginate_comments_url_route = @paginate_comments_url_route.blank? ? CommentsExtension::UrlCache : @paginate_comments_url_route
      %Q{<a href="#{@tag.locals.page.url}#{@paginate_comments_url_route}#{page}"#{attributes}>#{text}</a>}
    end
    
    def gap_marker
      '<span class="gap">&#8230;</span>'
    end

    def page_span(page, text, attributes = {})
      attributes = tag_options(attributes)
      "<span#{attributes}>#{text}</span>"
    end
  end
  
  class TagError < StandardError; end
  
  desc "Provides tags and behaviors to support comments in Radiant."

  desc %{
    Renders the contained elements if comments are enabled on the page.
  }
  tag "if_enable_comments" do |tag|
    tag.expand if (tag.locals.page.enable_comments?)
  end
  # makes more sense to me
  tag "if_comments_enabled" do |tag|
    tag.expand if (tag.locals.page.enable_comments?)
  end
  
  desc %{
    Renders the contained elements unless comments are enabled on the page.
  }
  tag "unless_enable_comments" do |tag|
    tag.expand unless (tag.locals.page.enable_comments?)
  end
  
  # makes more sense to me
  tag "unless_comments_enabled" do |tag|
    tag.expand unless (tag.locals.page.enable_comments?)
  end
  
  desc %{
    Renders the contained elements if the page has comments.
  }
  tag "if_comments" do |tag|
    tag.expand if tag.locals.page.has_visible_comments?
  end

  desc %{
    Renders the contained elements unless the page has comments. 
  }
  tag "unless_comments" do |tag|
    tag.expand unless tag.locals.page.has_visible_comments?
  end
  
  desc %{
    Renders the contained elements if the page has comments _or_ comment is enabled on it.
  }
  tag "if_comments_or_enable_comments" do |tag|
    tag.expand if(tag.locals.page.has_visible_comments? || tag.locals.page.enable_comments?)
  end

  desc %{
    Gives access to comment-related tags
  }

  tag "comments" do |tag|
    options = find_pagination_options(tag)    
    tag.locals.paginated_comments = tag.locals.page.comments.approved.paginate(options)
    
    tag.expand
  end

  desc %{
    Cycles through each comment and renders the enclosed tags for each.
    Use :per_page for setting comments per page option
  }
  tag "comments:each" do |tag|
    page = tag.locals.page

    comments = tag.locals.paginated_comments.to_a
    comments << page.selected_comment if page.selected_comment && page.selected_comment.unapproved?
    result = []
    comments.each_with_index do |comment, index|
      tag.locals.comment = comment
      tag.locals.index = index
      result << tag.expand
    end
    result
  end


  desc %{
    Renders pagination links with will_paginate
    The following optional attributes may be controlled:
    
    * id - the id to apply to the containing @<div>@
    * class - the class to apply to the containing @<div>@
    * previous_label - default: "« Previous"
    * prev_label - deprecated variant of previous_label
    * next_label - default: "Next »"
    * inner_window - how many links are shown around the current page (default: 4)
    * outer_window - how many links are around the first and the last page (default: 1)
    * separator - string separator for page HTML elements (default: single space)
    * page_links - when false, only previous/next links are rendered (default: true)
    * container - when false, pagination links are not wrapped in a containing @<div>@ (default: true)
    
    *Usage:*
    
    <pre><code><r:comments>
      <r:pages [id=""] [class="pagination"] [previous_label="&laquo; Previous"]
      [next_label="Next &raquo;"] [inner_window="4"] [outer_window="1"]
      [separator=" "] [page_links="true"] [container="true"]/>
    </r:pages></r:comments>
    </code></pre>
  }
  tag 'comments:pagination_links' do |tag|
    renderer = RadiantLinkRenderer.new(tag)
    
    options = {}
    
    [:id, :class, :previous_label, :prev_label, :next_label, :inner_window, :outer_window, :separator].each do |a|
      options[a] = tag.attr[a.to_s] unless tag.attr[a.to_s].blank?
    end
    options[:page_links] = false if 'false' == tag.attr['page_links']
    options[:container]  = false if 'false' == tag.attr['container']

    will_paginate tag.locals.paginated_comments, options.merge(:renderer => renderer)
  end

  desc %{
    Gives access to the particular fields for each comment.
  }
  tag "comments:field" do |tag|
    tag.expand
  end
  
  desc %{
    Renders the index number for this comment.
  }
  tag 'comments:field:index' do |tag|
    tag.locals.index + 1
  end
  
  %w(id author author_email author_url content content_html filter_id).each do |field|
    desc %{ Print the value of the #{field} field for this comment. }
    tag "comments:field:#{field}" do |tag|
      options = tag.attr.dup
      #options.inspect
      value = tag.locals.comment.send(field)
      value
    end
  end

  desc %{
    Renders the date a comment was created.

    *Usage:*
    <pre><code><r:date [format="%A, %B %d, %Y"] /></code></pre>
  }
  tag 'comments:field:date' do |tag|
    comment = tag.locals.comment
    format = (tag.attr['format'] || '%A, %B %d, %Y')
    date = comment.created_at
    date.strftime(format)
  end

  desc %{
    Renders a link if there's an author_url, otherwise just the author's name.
  }
  tag "comments:field:author_link" do |tag|
    if tag.locals.comment.author_url.blank?
      tag.locals.comment.author
    else
      %(<a href="#{tag.locals.comment.author_url}">#{tag.locals.comment.author}</a>)
    end
  end

  desc %{
    Renders the contained elements if the comment has an author_url specified.
  }
  tag "comments:field:if_author_url" do |tag|
    tag.expand unless tag.locals.comment.author_url.blank?
  end

  desc %{
    Renders the contained elements if the comment is selected - that is, if it is a comment
    the user has just posted
  }
  tag "comments:field:if_selected" do |tag|
    tag.expand if tag.locals.comment == tag.locals.page.selected_comment
  end

  desc %{
    Renders the contained elements if the comment has been approved
  }
  tag "comments:field:if_approved" do |tag|
    tag.expand if tag.locals.comment.approved?
  end

  desc %{
    Renders the contained elements if the comment has not been approved
  }
  tag "comments:field:unless_approved" do |tag|
    tag.expand unless tag.locals.comment.approved?
  end

  desc %{
    Renders a Gravatar URL for the author of the comment.
  }
  tag "comments:field:gravatar_url" do |tag|
    email = tag.locals.comment.author_email
    size = tag.attr['size']
    format = tag.attr['format']
    rating = tag.attr['rating']
    default = tag.attr['default']
    md5 = Digest::MD5.hexdigest(email)
    returning "http://www.gravatar.com/avatar/#{md5}" do |url|
      url << ".#{format.downcase}" if format
      if size || rating || default
        attrs = []
        attrs << "s=#{size}" if size
        attrs << "d=#{default}" if default
        attrs << "r=#{rating.downcase}" if rating
        url << "?#{attrs.join('&')}"
      end
    end
  end

  desc %{
    Renders a comment form.

    *Usage:*
    <r:comment:form [class="comments" id="comment_form"]>...</r:comment:form>
  }
  tag "comments:form" do |tag|
    attrs = tag.attr.symbolize_keys
    html_class, html_id = attrs[:class], attrs[:id]
    r = %Q{ <form action="#{tag.locals.page.url}#{'comments' unless Radiant::Config['comments.post_to_page?']}}
      r << %Q{##{html_id}} unless html_id.blank?
    r << %{" method="post" } #comlpete the quotes for the action
      r << %{ id="#{html_id}" } unless html_id.blank?
      r << %{ class="#{html_class}" } unless html_class.blank?
    r << '>' #close the form element
    r <<  tag.expand
    r << %{</form>}
    r
  end

  tag 'comments:error' do |tag|
    if comment = tag.locals.page.last_comment
      if on = tag.attr['on']
        if error = comment.errors.on(on)
          tag.locals.error_message = error
          tag.expand
        end
      else
        tag.expand if !comment.valid?
      end
    end
  end

  tag 'comments:error:message' do |tag|
    tag.locals.error_message
  end

  %w(text password hidden).each do |type|
    desc %{Builds a #{type} form field for comments.}
    tag "comments:#{type}_field_tag" do |tag|
      attrs = tag.attr.symbolize_keys
      r = %{<input type="#{type}"}
      r << %{ id="comment_#{attrs[:name]}"}
      r << %{ name="comment[#{attrs[:name]}]"}
      r << %{ class="#{attrs[:class]}"} if attrs[:class]
      if value = (tag.locals.page.last_comment ? tag.locals.page.last_comment.send(attrs[:name]) : attrs[:value])
        r << %{ value="#{value}" }
      end
      r << %{ />}
    end
  end

  %w(submit reset).each do |type|
    desc %{Builds a #{type} form button for comments.}
    tag "comments:#{type}_tag" do |tag|
      attrs = tag.attr.symbolize_keys
      r = %{<input type="#{type}"}
      r << %{ id="#{attrs[:name]}"}
      r << %{ name="#{attrs[:name]}"}
      r << %{ class="#{attrs[:class]}"} if attrs[:class]
      r << %{ value="#{attrs[:value]}" } if attrs[:value]
      r << %{ />}
    end
  end

  desc %{Builds a text_area form field for comments.}
  tag "comments:text_area_tag" do |tag|
    attrs = tag.attr.symbolize_keys
    r = %{<textarea}
    r << %{ id="comment_#{attrs[:name]}"}
    r << %{ name="comment[#{attrs[:name]}]"}
    r << %{ class="#{attrs[:class]}"} if attrs[:class]
    r << %{ rows="#{attrs[:rows]}"} if attrs[:rows]
    r << %{ cols="#{attrs[:cols]}"} if attrs[:cols]
    r << %{>}
    if content = (tag.locals.page.last_comment ? tag.locals.page.last_comment.send(attrs[:name]) : attrs[:content])
      r << content
    end
    r << %{</textarea>}
  end

  desc %{Build a drop_box form field for the filters avaiable.}
  tag "comments:filter_box_tag" do |tag|
    attrs = tag.attr.symbolize_keys
    value = attrs.delete(:value)
    name = attrs.delete(:name)
    r =  %{<select name="comment[#{name}]"}
    unless attrs.empty?
      r << " "
      r << attrs.map {|k,v| %Q(#{k}="#{v}") }.join(" ")
    end
    r << %{>}

    TextFilter.descendants.each do |filter|

      r << %{<option value="#{filter.filter_name}"}
      r << %{ selected="selected"} if value == filter.filter_name
      r << %{>#{filter.filter_name}</option>}

    end

    r << %{</select>}
  end

  desc %{Prints the number of comments. }
  tag "comments:count" do |tag|
    tag.locals.page.comments.approved.count
  end
  
  
  tag "recent_comments" do |tag|
    tag.expand
  end
  
  desc %{Returns the last [limit] comments throughout the site.
    
    *Usage:*
    <pre><code><r:recent_comments:each [limit="10"]>...</r:recent_comments:each></code></pre>
    }
  tag "recent_comments:each" do |tag|
    limit = tag.attr['limit'] || 10
    comments = Comment.approved.recent.all(:limit => limit)
    result = []
    comments.each_with_index do |comment, index|
      tag.locals.comment = comment
      tag.locals.index = index
      tag.locals.page = comment.page
      result << tag.expand
    end
    result
  end
  
  desc %{
    Use this to prevent spam bots from filling your site with spam.
    
    *Usage:*
    <pre><code>What day comes after Monday? <r:comments:spam_answer_tag answer="Tuesday" /></code></pre>
  }
  tag "comments:spam_answer_tag" do |tag|
      attrs = tag.attr.symbolize_keys
      valid_spam_answer = attrs[:answer] || 'hemidemisemiquaver'
      md5_answer = Digest::MD5.hexdigest(valid_spam_answer.to_slug)
      r = %{<input type="text" id="comment_spam_answer" name="comment[spam_answer]"}
      r << %{ class="#{attrs[:class]}"} if attrs[:class]
      if value = (tag.locals.page.last_comment ? tag.locals.page.last_comment.send(:spam_answer) : '')
        r << %{ value="#{value}" }
      end
      r << %{ />}
      r << %{<input type="hidden" name="comment[valid_spam_answer]" value="#{md5_answer}" />}
  end

  desc %{
    Render the contained elements if using the simple spam filter.
  }
  tag "if_comments_simple_spam_filter_enabled" do |tag|
    tag.expand if Comment.simple_spam_filter_enabled?
  end

  desc %{
    Render the contained elements unless using the simple spam filter.
  }
  tag "unless_comments_simple_spam_filter_enabled" do |tag|
    tag.expand unless Comment.simple_spam_filter_enabled?
  end
  
  private
  
  def find_pagination_options(tag)    
    options = {}

    options[:page] = tag.attr['page'] || @request.path[/^#{Regexp.quote(tag.locals.page.url)}#{Regexp.quote(CommentsExtension::UrlCache)}(\d+)\/?$/, 1]

    options[:per_page] = tag.attr['per_page'] || CommentsExtension::ShowPerPage
    raise TagError.new('the per_page attribute of the comments tag must be a positive integer') unless options[:per_page].to_i > 0
    
    by = (tag.attr[:by] || 'created_at').strip
    order = (tag.attr[:order] || 'desc').strip 
    order_string = ''
    
    if Comment.new.attributes.keys.include?(by)
      order_string << by
    else
      raise TagError.new('the by attribute of the comments tag must specify a valid field name')
    end

    if order =~ /^(a|de)sc$/i
      order_string << " #{order.upcase}"
    else
      raise TagError.new('the order attribute of the comments tag must be either "asc" or "desc"')
    end
    options[:order] = order_string

    options
  end
  
end
