import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import discourseComputed from "discourse-common/utils/decorators";
import { htmlSafe } from "@ember/template";

export default class EngagementPathway extends Component {
  @service messageBus;
  @service currentUser;
  @service router;

  @tracked tasks = [];
  @tracked message = '';

  @tracked endlevel = false;
  @tracked info = [];
  @tracked linksHeader = '';
  @tracked links = [];

  @tracked emojiSrc = '/images/emoji/twitter/fireworks.png?v=12';
  @tracked showEmoji = true;

  @tracked showHere = false;

  constructor() {
    super(...arguments);
    this.#setShowHere();
    this.router.on("routeDidChange", this, this.#setShowHere);
    this.subscribe();
    if (this.currentUser) {
      this._processMessage(this.currentUser.engagement_info || {level:1, goals: { a: true }} );
    } else {
      this._processMessage({level: 0});
    }
  }

  willDestroy() {
    this.unsubscribe();
    this.router.off("routeDidChange", this, this.#setShowHere);
  }

  #setShowHere() {
    this.showHere = (['discovery.latest', 'discovery.unread', 'discovery.top', 'discovery.new', 'discovery.categories'].includes(this.router.currentRouteName));
  }

  @bind
  subscribe() {
    if (this.currentUser) {
      const channel = "/engagement_pathway";
      this.messageBus.subscribe(channel, this._processMessage);
    }
  }

  @bind
  unsubscribe() {
    this.messageBus.unsubscribe("/engagement_pathway", this._processMessage);
  }

  @bind
  _processMessage(data) {
    if (data.level < 5) {
      var t = [];
      const goals = ['a', 'b', 'c'];
      goals.forEach((goal) => {
        var completed = '';
        if (data.goals) {
          completed = (data?.goals[goal] ? 'completed' : '');
        }
        t.push({
          url:  I18n.t(`engagement_pathway.level_${data.level}${goal}_link`),
          icon: completed ? 'check-circle' : I18n.t(`engagement_pathway.level_${data.level}${goal}_icon`),
          text: I18n.t(`engagement_pathway.level_${data.level}${goal}_text`),
          status: completed
        });
      });
      this.endlevel = false
      this.tasks = t;
      this.message = htmlSafe(I18n.t(`engagement_pathway.level_${data.level}_message`));
    } else {
      this.info = [
        { html: I18n.t("engagement_pathway.endlevel_contrib", { count: (data.contribution_count || 0).toLocaleString('en-US', { useGrouping: true, groupingSeparator: ',' }) })},
        { html: I18n.t("engagement_pathway.endlevel_viewed", { count: (data.posts_read_count || 0).toLocaleString('en-US', { useGrouping: true, groupingSeparator: ',' }) })},
        { html: I18n.t("engagement_pathway.endlevel_liked", { count: (data.likes_received || 0).toLocaleString('en-US', { useGrouping: true, groupingSeparator: ',' }) })}
      ];
      this.linksHeader = htmlSafe(I18n.t(`engagement_pathway.level_${data.level}_header`));
      this.links = [
        { html: I18n.t(`engagement_pathway.level_${data.level}_html_1`) },
        { html: I18n.t(`engagement_pathway.level_${data.level}_html_2`) },
        { html: I18n.t(`engagement_pathway.level_${data.level}_html_3`) },
      ];

      var score = (data.contribution_count || 0) + (data.likes_received || 0)
      var emoji_from = data.emoji_from || 0;
      this.showEmoji =  (emoji_from > 0) && (score >= emoji_from) && (score <= (data.emoji_to || 0))
      this.emojiSrc = `/images/emoji/twitter/${data.emoji}.png?v=12`

      this.endlevel = true;
    }
  }
}


