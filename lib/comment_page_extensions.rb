module CommentPageExtensions
  def self.included(base)
    base.class_eval do
      alias_method_chain :process, :comments
      alias_method_chain :find_by_url, :comments_pagination
      
      has_many :comments, :dependent => :delete_all, :order => "created_at ASC"
      attr_accessor :last_comment
      attr_accessor :selected_comment
    end
  end
 
  def find_by_url_with_comments_pagination(url, live = true, clean = true)
    @paginate_comments_url_route = @paginate_comments_url_route.blank? ? CommentsExtension::UrlCache : @paginate_comments_url_route
    url = clean_url(url) if clean
    if url =~ %r{^#{ self.url }#{@paginate_comments_url_route}\d+\/$}
      self
    else
      find_by_url_without_comments_pagination(url, live, clean)
    end
  end

  def has_visible_comments?
    !(comments.approved.empty? && selected_comment.nil?)
  end

  def process_with_comments(request, response)
    if Radiant::Config['comments.post_to_page?'] && request.post? && request.parameters[:comment]
      begin
        comment = self.comments.build(request.parameters[:comment])
        comment.request = self.request = request
        comment.save!

        if Radiant::Config['comments.notification'] == "true"
          if comment.approved? || Radiant::Config['comments.notify_unapproved'] == "true"
            CommentMailer.deliver_comment_notification(comment)
          end
        end
        if comment.approved?
          absolute_url = "#{request.protocol}#{request.host_with_port}#{relative_url_for(url, request)}#comment-#{comment.id}"
          response.redirect(absolute_url, 303)
          return
        else
          self.selected_comment = comment
        end
      rescue ActiveRecord::RecordInvalid
        self.last_comment = comment
      end
    end
    process_without_comments(request, response)
  end
end