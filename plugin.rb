# name: discourse-engagement-pathway
# about: Discourse Engagement Pathway plugin
# version: 1.0
# authors: richard@communiteq.com
# url: https://www.communiteq.com/

enabled_site_setting :engagement_pathway_enabled

register_asset "stylesheets/common.scss"

after_initialize do

  register_user_custom_field_type('engagement_info', :json)

  add_to_serializer(:current_user, :engagement_info) do 
    object.custom_fields['engagement_info']
  end

  require_dependency "user"
  class ::User
    def set_current_ep_level(level, goals)
      info = {
        level: level,
        goals: goals
      }
      self.custom_fields[:engagement_info] = info
      self.save_custom_fields

      MessageBus.publish('/engagement_pathway', info, user_ids: [self.id])
    end

    def evaluate_ep_level
      current_info = self.custom_fields[:engagement_info] || {level: 1, goals: {a: false, b: false, c: false}}
      puts current_info.inspect

      changed = false
      failed = false

      until failed do
        current_level = current_info[:level]
        ['a', 'b', 'c'].each do |goal|
          unless current_info[:goals][goal]
            begin
              req = SiteSetting.send("engagement_pathway_level_#{current_level}#{goal}")
              req_type, req_amnt, req_cat, req_ncat = req.split(";")

              case req_type
              when 'R' # read
                ok = self.user_stat.posts_read_count >= req_amnt.to_i
              when 'L' # like
                ok = self.user_stat.likes_given >= req_amnt.to_i
              when 'T' # create topic
                cnt = self.topics
                cnt = cnt.where(category_id: req_cat.split(',')) unless req_cat.nil? || req_cat.empty?
                cnt = cnt.where.not(category_id: req_ncat.split(',')) unless req_ncat.nil? || req_ncat.empty?
                ok = cnt.count >= req_amnt.to_i
              when 'P' # create post
                cnt = Post.joins(:topic).where(user_id: self.id)
                cnt = cnt.where(topics: {category_id: req_cat.split(',')}) unless req_cat.nil? || req_cat.empty?
                cnt = cnt.where.not(topics: {category_id: req_ncat.split(',')}) unless req_ncat.nil? || req_ncat.empty?
                ok = cnt.count >= req_amnt.to_i
              when 'I' # invite
                cnt = self.invites
                ok = cnt.count >= req_amnt.to_i
              when 'V'
                ok = true
              end
            rescue => e
              ok = false
            end
            if ok
              current_info[:goals][goal] = true
              changed = true
            else
              failed = true
            end
          end
        end # a b c
        break if failed

        current_info[:level] = current_level + 1
        current_info[:goals] = {a: false, b: false, c: false}
        if current_level > 10
          failed = true
        end
      end # until failed
      
      if changed
        self.set_current_ep_level(current_info[:level], current_info[:goals])
      end
    end
  end

  module ::EPExtensions
    module InviteExtension
      def self.included(base)
        base.after_create :ep_after_create
      end

      def ep_after_create
        if SiteSetting.engagement_pathway_enabled
          user = User.find(self.invited_by_id)
          user.evaluate_ep_level if user
        end
      end
    end
  end

  class ::Invite
    include ::EPExtensions::InviteExtension
  end

  DiscourseEvent.on(:post_created) do |post|
    if SiteSetting.engagement_pathway_enabled
      post&.user&.evaluate_ep_level
    end
  end

  DiscourseEvent.on(:like_created) do |like|
    if SiteSetting.engagement_pathway_enabled
      like&.user&.evaluate_ep_level
    end
  end
end
