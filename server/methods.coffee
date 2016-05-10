if Meteor.isServer
  riotApiKey = Meteor.settings.riotApiKey

  keyify = (str) ->
    str = str.toLowerCase().replace(/\s/g, '')
    return str

  matchifySummoner = (summId) ->
    # if summoner id, matchify only that
    # and return it for use
    if summId
      # HACKED should be able to call this for creating a new summoner
    else
      summoner = Summoners.findOne({matches: null})
      count = Summoners.find({matches: null}).count()
      if summoner
        console.log count, 'left!'
        console.log 'found', summoner.riotName
        summId = Number(summoner.riotId)
        riotApiMatchesOfSummonerUrl = 'https://na.api.pvp.net/api/lol/na/v2.2/matchlist/by-summoner/' + summId + '?api_key=' + riotApiKey
        getMatchesOfSummonerAsync = Meteor.wrapAsync HTTP.get
        resultOfMatchesOfSummonerAsync = getMatchesOfSummonerAsync riotApiMatchesOfSummonerUrl, {}, (error, response) ->
          if error
            console.log error
            console.log 'error - timeout and try again'
            Meteor.setTimeout ( ->
              console.log 'trying again'
              matchifySummoner()
            ), 1000
          else if response
            console.log 'made contact! Grab matches and push to summoner'
            matchesPulled = response.data.matches
            Summoners.update({riotId: summId}, {$set: {matches: matchesPulled}})
            console.log 'matches added to summoner', summId
            console.log 'recalling method...'
            Meteor.setTimeout ( ->
              matchifySummoner()
            ), 1000
      else
        return 'done'

  Meteor.methods
    serverifyNA: ->
      #add NA as the server for seed db, since they were all pulled from there
      length = Summoners.find({}).count() - 1
      Summoners.find({}).forEach (summoner, i) ->
        Summoners.update({riotId: summoner.riotId}, {$set: {server: 'na'}})
        console.log i, 'of', length
        if i is length
          console.log 'done assigning everyone to NA'
          return 'done assigning everyone to NA'
    pruneMatches: ->
      length = Summoners.find({}).count() - 1
      Summoners.find({}).forEach (summoner, i) ->
        #for each summoner get matches
        matches = summoner.matches
        matchesNew = []
        #loop through each match
        matches.forEach (match) ->
          #and make a new array for the match with only the elements we need
          matchNew = {}
          matchNew.matchId = match.matchId
          matchNew.champion = match.champion
          matchNew.lane = match.lane
          matchNew.role = match.role
          matchesNew.push(matchNew)

        Summoners.update({riotId: summoner.riotId}, {$set: {matches: matchesNew}})
        console.log i, 'of', length
        if i is length
          console.log 'done pruning matches'
          return 'done pruning matches'
    findSummoner: (args) ->
      console.log args
      name = args[0]
      server = args[1]
      summonerName = keyify(name)
      summoner = Summoners.findOne({riotNameToKey: summonerName, server: server})

      # if summoner exists, retutrn the id and link to the page
      if summoner
        return [summoner.riotId, summoner.server]
      # otherwise call the riot api and create the summoner
      else
        #get core summoner
        riotApiSummonerByNameUrl = 'https://' + server + '.api.pvp.net/api/lol/' + server + '/v1.4/summoner/by-name/' + name + '?api_key=' + riotApiKey
        getSummonerByNameAsync = Meteor.wrapAsync HTTP.get
        resultOfSummonerByNameAsync = getSummonerByNameAsync riotApiSummonerByNameUrl, {}

        # Squish object one level
        summoner = JSON.parse resultOfSummonerByNameAsync.content
        for summonerObj of summoner
          summoner = summoner[summonerObj]

        #get summoner masteries
        riotChampMasteryApiUrl = 'https://' + server + '.api.pvp.net/championmastery/location/' + server + '1/player/' + summoner.id + '/champions?api_key=' + riotApiKey
        getChampMasteryAsync = Meteor.wrapAsync HTTP.get
        resultOfChampMasteryAsync = getChampMasteryAsync riotChampMasteryApiUrl, {}
        latestChampMastery = JSON.parse(resultOfChampMasteryAsync.content)

        #get summoner matches
        riotApiMatchesOfSummonerUrl = 'https://' + server + '.api.pvp.net/api/lol/' + server + '/v2.2/matchlist/by-summoner/' + summoner.id + '?api_key=' + riotApiKey
        getMatchesOfSummonerAsync = Meteor.wrapAsync HTTP.get
        resultOfMatchesOfSummonerAsync = getMatchesOfSummonerAsync riotApiMatchesOfSummonerUrl, {}
        matches = resultOfMatchesOfSummonerAsync.data.matches

        # add new summoner
        newSummoner =
          riotId: summoner.id
          riotName: summoner.name
          riotNameToKey: keyify summoner.name
          initialPoll: false
          latestChampionMastery: latestChampMastery
          matches: matches
          server: server
        Summoners.insert(newSummoner)
        # and return the id for linking to
        return [newSummoner.riotId, newSummoner.server]

    updateBreakdown: (args) ->
      change = args[0]
      if change is 'toChampions'
        role = args[1]
        summonerId = args[2]
        # find summoner masteries
        summoner = Summoners.findOne({riotId: summonerId})
        mastery = summoner.latestChampionMastery
        # filter for the selected role
        mastery = mastery.filter (value) ->
          championId = value.championId
          champion = Champions.findOne({championId: championId})
          tags = champion.championTags
          if tags.indexOf(role) isnt -1
            return value
        labels = []
        champions = []
        mastery.forEach (champion) ->
          name = Champions.findOne({championId: champion.championId}).championName
          labels.push name
          oneChampion = {}
          oneChampion.meta = name
          oneChampion.value = champion.championPoints
          champions.push oneChampion
        data =
          labels: labels
          series: champions
        return data
      else if change is 'toChampion'
        championPicked = args[1]
        summonerId = args[2]
        # find summoner matches
        summoner = Summoners.findOne({riotId: summonerId})
        matches = summoner.matches

        # loop through each match, looking for matches with the champion picked
        matches = matches.filter (value) ->
          championId = value.champion
          champion = Champions.findOne({championId: championId})
          championName = champion.championName
          if championPicked is championName
            return value

        #loop through each one, grabbing lane and role
        labels = []
        laneCounts = {}
        lanes = []
        matches.forEach (match) ->
          lane = match.lane
          # normalize all possible values of lane to human-friendly ones
          # MID, MIDDLE, TOP, JUNGLE, BOT, BOTTOM
          switch lane
            when 'MID'
              lane = 'Mid'
            when 'MIDDLE'
              lane = 'Mid'
            when 'TOP'
              lane = 'Top'
            when 'JUNGLE'
              lane = "Jungle"
            when 'BOT'
              lane = 'Bot'
            when 'BOTTOM'
              lane = 'Bot'
            else
              lane = 'Freeform'
          # add lane if it doesn't exist
          if labels.indexOf(lane) is -1
            labels.push(lane)
            laneCounts[lane] = 1
          else
            # otherwise just add to the count
            laneCounts[lane] += 1
        #when all the values have been collected, write them correctly into the data array
        labels.forEach (label) ->
          oneLane = {}
          oneLane.meta = label
          oneLane.value = laneCounts[label]
          lanes.push oneLane
        data =
          labels: labels
          series: lanes
        return data
      return 'Houston, we have a problem'
    getMatchesOfSummoner: (summId) ->
      riotApiMatchesOfSummonerUrl = 'https://na.api.pvp.net/api/lol/na/v2.2/matchlist/by-summoner/' + summId + '?api_key=' + riotApiKey
      getMatchesOfSummonerAsync = Meteor.wrapAsync HTTP.get
      resultOfMatchesOfSummonerAsync = getMatchesOfSummonerAsync riotApiMatchesOfSummonerUrl, {}
      matchesPulled = resultOfMatchesOfSummonerAsync.data.matches
      summoner = Summoners.findOne({riotId: Number(summId)})
      # HACK ideally we should check for the date and only sort for new matches
      # but ain't nobody got time for that right now
      # sorry riot servers
      # sorry my servers
      console.log 'created matches'
      Summoners.update({riotId: Number(summId)}, {$set: {matches: matchesPulled}})
      return Summoners.findOne({riotId: Number(summId)})
    matchifySummoners: ->
      return matchifySummoner()
    keyifySummoners: ->
      length = Summoners.find({}).count() - 1
      Summoners.find({}).forEach (summoner, i) ->
        summonerKey = keyify summoner.riotName
        unless summoner.riotNameToKey
          Summoners.update({riotId: summoner.riotId}, {$set: {riotNameToKey: summonerKey}})
          console.log 'added key:', summonerKey, 'to', summoner.riotName
        if i is length
          return console.log 'done adding keys'
    getSummoner: (summName) ->
      riotApiSummonerByNameUrl = 'https://na.api.pvp.net/api/lol/na/v1.4/summoner/by-name/' + summName + '?api_key=' + riotApiKey
      getSummonerByNameAsync = Meteor.wrapAsync HTTP.get
      resultOfSummonerByNameAsync = getSummonerByNameAsync riotApiSummonerByNameUrl, {}

      # Squish object one level
      summoner = JSON.parse resultOfSummonerByNameAsync.content
      for summonerObj of summoner
        summoner = summoner[summonerObj]

      # Prep new object for the database
      if Summoners.findOne({riotId: summoner.id})
        return "summoner exists"
      newSummoner =
        riotId: summoner.id
        riotName: summoner.name
        riotNameToKey: keyify summoner.summonerName
        initialPoll: false
      Summoners.insert(newSummoner)
      return "summoner added!"
    getSummonerMatches: (summoner) ->
      if summoner
        summoner = keyify summoner
        seed = Summoners.findOne({riotNameToKey: summoner})
      else if !seed
        # Find a user who hasn't been polled yet
        seed = Summoners.findOne({initialPoll: false})
      console.log summoner
      console.log seed
      summId = seed.riotId
      Summoners.update({riotId: summId}, {$set: {initialPoll: true}})
      riotMatchListApiUrl = 'https://na.api.pvp.net/api/lol/na/v2.2/matchlist/by-summoner/' + summId + '?api_key=' + riotApiKey
      getMatchListAsync = Meteor.wrapAsync HTTP.get
      resultOfMatchListAsync = getMatchListAsync riotMatchListApiUrl, {}

      content = JSON.parse(resultOfMatchListAsync.content)
      matches = content.matches

      matchIds = []
      matches.forEach (el) ->
        matchIds.push(el.matchId)

      getMatchAsync = Meteor.wrapAsync HTTP.get

      matchIds.forEach (el, i) ->
        Meteor.setTimeout ( ->
          riotMatchApiUrl = 'https://na.api.pvp.net/api/lol/na/v2.2/match/' + el + '?includeTimeline=false&api_key=' + riotApiKey
          resultOfMatchAsync = getMatchAsync riotMatchApiUrl, {}
          matchContent = JSON.parse(resultOfMatchAsync.content)
          matchParticipants = matchContent.participantIdentities
          matchParticipants.forEach (participant) ->
            summoner = participant['player']

            # Prep new object for the database
            if Summoners.findOne({riotId: summoner.summonerId})
              return console.log "summoner", summoner.summonerName, "exists"
            newSummoner =
              riotId: summoner.summonerId
              riotName: summoner.summonerName
              riotNameToKey: keyify summoner.summonerName
              initialPoll: false
            Summoners.insert(newSummoner)
            return console.log "summoner", summoner.summonerName, "added"
        ), 1500 * i
        if i is matchIds.length - 1
          return console.log 'done adding users!'

    getChampionMasteries: ->
      initialSummonerPull = []
      Summoners.find({}).forEach (summoner) ->
        unless summoner.latestChampionMastery
          initialSummonerPull.push summoner
      initialSummonerPull.forEach (summoner, index) ->
        Meteor.setTimeout ( ->
          riotChampMasteryApiUrl = 'https://na.api.pvp.net/championmastery/location/na1/player/' + summoner.riotId + '/champions?api_key=' + riotApiKey
          getChampMasteryAsync = Meteor.wrapAsync HTTP.get
          resultOfChampMasteryAsync = getChampMasteryAsync riotChampMasteryApiUrl, {}
          latestChampMastery = JSON.parse(resultOfChampMasteryAsync.content)
          Summoners.update({riotId: summoner.riotId}, {$set: {latestChampionMastery: latestChampMastery}})
          return console.log 'updated', summoner.riotName, index, 'of', initialSummonerPull.length - 1
        ), 1500 * index
        if index is initialSummonerPull.length - 1
          return console.log "done adding champion masteries!"
