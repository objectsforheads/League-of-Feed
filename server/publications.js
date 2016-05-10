Meteor.publish('allSummoners', function () {
  return Summoners.find({});
});

Meteor.publish('aSummoner', function(summonerId) {
  return Summoners.find({ riotId: summonerId });
});

Meteor.publish('allChampions', function() {
  return Champions.find({})
})
