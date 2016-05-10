riotApiKey = Meteor.settings.riotApiKey
riotApiChampionsUrl = 'https://global.api.pvp.net/api/lol/static-data/na/v1.2/champion?champData=blurb,info,tags&api_key=' + riotApiKey
getChampionsAsync = Meteor.wrapAsync HTTP.get
resultOfChampionsAsync = getChampionsAsync riotApiChampionsUrl, {}
version = JSON.parse(resultOfChampionsAsync.content).version
champions = JSON.parse(resultOfChampionsAsync.content).data
# HACK hardcoding version check, make it automatic later
if version is '6.9.1'
  return console.log 'champions up to date!'
else
  Champions.remove({})
  for champion of champions
    newChampion =
      championId: champions[champion].id
      championKey: champions[champion].key
      championName: champions[champion].name
      championTitle: champions[champion].title
      championBlurb: champions[champion].blurb
      championStats: champions[champion].info
      championTags: champions[champion].tags
    Champions.insert(newChampion)
    console.log "champion", newChampion.championName, "added"
