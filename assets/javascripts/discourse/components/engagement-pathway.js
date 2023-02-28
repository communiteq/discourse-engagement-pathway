import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";

export default class EngagementPathway extends Component {
  @service messageBus;
  @service currentUser;

  @tracked level = 0;

  @tracked tasks = [];
  @tracked message = ''

  constructor() {
    super(...arguments);
    this.subscribe();
    if (this.currentUser) {
      this._processMessage(this.currentUser.engagement_info || {level:1} );
    } else {
      this._processMessage({level: 0});
    }
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
    var t = [];
    const goals = ['a', 'b', 'c'];
    goals.forEach((goal) => {
      var completed = '';
      if (data.goals) {
        completed = (data?.goals[goal] ? 'completed' : '');
      }
      t.push({
        url:  I18n.t(`engagement_pathway.level_${data.level}${goal}_link`),
        icon: I18n.t(`engagement_pathway.level_${data.level}${goal}_icon`), 
        text: I18n.t(`engagement_pathway.level_${data.level}${goal}_text`), 
        status: completed
      });
    });
    this.tasks = t;
    this.message = I18n.t(`engagement_pathway.level_${data.level}_message`);
  }
}


