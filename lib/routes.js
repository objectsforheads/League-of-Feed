FlowRouter.route('/', {
  action: function() {
    BlazeLayout.render("mainLayout", {content: "homepage"});
  }
});

FlowRouter.route( '/summoner/:server/:riotId', {
  action: function (params) {
    BlazeLayout.render("mainLayout", {content: "summonerSummary"});
  }
});
