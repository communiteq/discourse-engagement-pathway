# name: discourse-engagement-pathway
# about: Discourse Engagement Pathway plugin
# version: 1.5.1
# authors: Communiteq
# url: https://www.communiteq.com/

enabled_site_setting :engagement_pathway_enabled

register_asset "stylesheets/common.scss"
register_asset "stylesheets/mobile.scss", :mobile
register_asset "stylesheets/desktop.scss", :desktop

after_initialize do

  register_user_custom_field_type('engagement_info', :json)

  add_to_serializer(:current_user, :engagement_info) do
    object.custom_fields['engagement_info']
  end

  require_dependency "user"
  class ::User
    def recalculate_ep_level
      self.custom_fields.delete("engagement_info")
      self.evaluate_ep_level
    end

    def set_current_ep_level(current_info)
      info = {
        level: current_info[:level],
        goals: current_info[:goals].map { |k, v| [k.to_s, v] }.to_h,
        emoji: current_info[:emoji] || '',
        emoji_from: current_info[:emoji_from] || 0,
        emoji_to: current_info[:emoji_to] || 0,
        likes_received: self&.user_stat&.likes_received,
        posts_read_count: self&.user_stat&.posts_read_count,
        contribution_count: self&.user_stat&.topic_count + self&.user_stat&.post_count,
      }.map { |k, v| [k.to_s, v] }.to_h

      if self.custom_fields[:engagement_info] != info
        self.custom_fields[:engagement_info] = info
        self.save_custom_fields
        MessageBus.publish('/engagement_pathway', info, user_ids: [self.id])
      end
      info
    end

    def evaluate_ep_level
      current_info = self.custom_fields[:engagement_info].dup || {level: 1, goals: {a: true, b: false, c: false}}

      changed = false
      failed = false

      if current_info[:level] < 5
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
      end # level < 5

      if current_info[:level] >= 5
        emoji_from = current_info[:emoji_from] || 0
        score = self&.user_stat&.topic_count + self&.user_stat&.post_count + self&.user_stat&.likes_received
        if emoji_from == 0 ## first time
          current_info[:emoji_from] = score
          current_info[:emoji_to] = score + 10
          current_info[:emoji] = 'fireworks'
          changed = true
        else
          if score > current_info[:emoji_to]
            current_info[:emoji_from] = score + rand(25) + 10
            current_info[:emoji_to] = current_info[:emoji_from] + 10
            choices = [
              "fireworks", "pray", "star_struck", "partying_face", "sunglasses", "boom", "+1",
              "raised_hands", "seedling", "fire", "tada", "medal_military", "trophy",
              "white_check_mark", "smiley", "yellow_heart", "clap", "rocket",
              "stars", "medal_sports", "ballot_box_with_check"
            ]
            current_info[:emoji] = choices[rand(choices.length)]
            changed = true
          end
        end
      end

      is_member = self.groups.pluck(:name).to_a.include?(SiteSetting.engagement_pathway_boss_group)
      if current_info[:level] == 5
        if is_member
          current_info[:level] = 6
          changed = true
        end
      end
      if current_info[:level] == 6
        if !is_member
          current_info[:level] = 5
          changed = true
        end
      end

      self.set_current_ep_level(current_info)
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

  DiscourseEvent.on(:user_added_to_group) do |user|
    if SiteSetting.engagement_pathway_enabled
      user&.evaluate_ep_level
    end
  end

  DiscourseEvent.on(:user_removed_from_group) do |user|
    if SiteSetting.engagement_pathway_enabled
      user&.evaluate_ep_level
    end
  end

  DiscourseEvent.on(:post_created) do |post|
    if SiteSetting.engagement_pathway_enabled
      post&.user&.evaluate_ep_level
    end
  end

  DiscourseEvent.on(:like_created) do |like|
    if SiteSetting.engagement_pathway_enabled
      like&.user&.evaluate_ep_level
      like&.post&.user&.evaluate_ep_level
    end
  end
end
