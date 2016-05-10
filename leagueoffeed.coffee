if Meteor.isClient
  clearGraphLabels = ->
    $('.segment__label').each ->
      $(this).remove()
  moveChartLegend = ->
    $('.chart__legend').empty()
    legend = $('.ct-legend').detach()
    legend.prependTo('.chart__legend')
    $('.ct-legend').show()
    legend = null
  generateGraphLabels = ->
    # HACK we're using the labels as our pointers to position the new, cooler labels
    $labels = $('.ct-chart-donut > g:not(".ct-series")').children()
    # grab the diameter for angle calculations
    diameter = $('.ct-chart-donut').width()
    # for each label, pull its coordinates and quadrant so we know where to set our new labels
    $labels.each ->
      x = $(this).attr('dx')
      y = $(this).attr('dy')
      radius = diameter/2
      deltaX = x - radius
      deltaY = y - radius
      angle = Math.atan(Math.abs(deltaX/deltaY)) * 180/Math.PI
      quadrant = 1
      #accomodate quadrants
      #q2
      if deltaX >= 0 and deltaY >= 0
        angle = 180 - angle
        quadrant = 2
      #q3
      else if deltaX < 0 and deltaY >= 0
        angle +=180
        quadrant = 3
      #q4
      else if deltaX < 0 and deltaY < 0
        angle = 360 - angle
        quadrant = 4
      xRel = x/diameter * 100
      yRel = y/diameter * 100
      name = $(this).text()
      # append the label where appropriate
      $('.roles-segment-toggle').append('<div data-label="' + name + '" class="segment__label q' + quadrant + '" style="top: ' + yRel + '%; left: ' + xRel + '%"><div class="label__content"><h3>' + name + '</h3><span class="subheading">See Breakdown</span></div>')
  #start counter at 0
  Session.setDefault 'counter', 0

  Template.summonerSummary.onCreated ->
    @subscribe('allChampions')
  Template.summonerSummary.onRendered ->
    $('body').removeClass()
    $('body').addClass('summoner-page')

    @autorun =>
      summonerId = Number(FlowRouter.getParam('riotId'))
      @subscribe('aSummoner', summonerId)

    Session.set 'maxPts', 0
    Session.set 'rolesChartLabel', 0
    Session.set 'loadingRolesBreakdown', 0
    Session.set 'chartScope', 'roles'
    Session.set 'currentRoleBreakdown', null
    Session.set 'chart', null

  Template.summonerSummary.helpers
    # find summoner
    summoner: ->
      summonerId = Number(FlowRouter.getParam('riotId'))
      summonerServer = FlowRouter.getParam('server')
      summoner = Summoners.findOne({riotId: summonerId, server: summonerServer})
      return summoner
    # get mastery breakdown
    championMasteryPoints: ->
      champion = Session.get 'labelContext'
      pts = 0
      @latestChampionMastery.forEach (el) ->
        if Champions.findOne({championId: el.championId}).championName is champion
          pts = el.championPoints
      pts = pts.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")
      return pts
    championsMastered: ->
      count = 0
      @latestChampionMastery.forEach (el) ->
        if el.championPoints > 21600
          count += 1
      return count
    championsInProgressMastery: ->
      count = 0
      @latestChampionMastery.forEach (el) ->
        if el.championPoints <= 21600
          count += 1
      return count
    championsNoPoints: ->
      return Champions.find({}).count() - @latestChampionMastery.length
    # get champion roles
    playedChampionRoles: ->
      # TODO I don't remember what this does, but it does something important probably
      flag = Session.get 'loadingRolesBreakdown'
      roles = {}
      pts = 0
      @latestChampionMastery.forEach (el) ->
        if el.championPoints > pts
          pts = el.championPoints
      @latestChampionMastery.forEach (el) ->
        #loop through each mastery
        #determine the percent points to give
        relPercentPt = Math.round( el.championPoints/pts * 100 )
        #get the champion roles from the db
        champion = Champions.findOne({championId: el.championId})
        #for each champion, associate the relative percent point with the tag
        tags = champion.championTags
        tags.forEach (tag) ->
          if tag of roles
            #role exists, push number
            roles[tag] += relPercentPt
          else
            roles[tag] = 0
            roles[tag] += relPercentPt
      #then make the tags a relative % to each other
      totalRolePts = 0
      for role of roles
        totalRolePts += roles[role]
      for role of roles
        roles[role] = Math.round( roles[role]/totalRolePts * 100 )
      Session.set 'roleBreakdown', roles
      #build and apply chart
      if roles
        clearGraphLabels()
        labels = []
        roleBreakdown = []
        for role of roles
          labels.push role
          oneRole = {}
          oneRole.meta = role
          oneRole.value = roles[role]
          roleBreakdown.push oneRole
        # HACK force wait for chart loading
        Meteor.setTimeout ( ->
          $('.ct-chart').attr('data-scope', 'roles')
          data =
            labels: labels
            series: roleBreakdown
          options =
            donut: true
            chartPadding: 30,
            labelOffset: 50,
            labelDirection: 'explode'
            plugins: [
              Chartist.plugins.legend({clickable: false})
            ]
          Session.set 'chart', data
          chart = new (Chartist.Pie)('.ct-chart', data, options)
          chart.on 'draw', (data) ->
            if data.type == 'slice'
              # Get the total path length in order to use for dash array animation
              pathLength = data.element._node.getTotalLength()
              # Set a dasharray that matches the path length as prerequisite to animate dashoffset
              data.element.attr 'stroke-dasharray': pathLength + 'px ' + pathLength + 'px'
              # Create animation definition while also assigning an ID to the animation for later sync usage
              animationDefinition = 'stroke-dashoffset':
                id: 'anim' + data.index
                dur: 500
                from: -pathLength + 'px'
                to: '0px'
                fill: 'freeze'
              # HACK removing smooth animating circle in favor of all segments animating because I need animationend and haven't found it yet
              # If this was not the first slice, we need to time the animation so that it uses the end sync event of the previous animation
              #if data.index isnt 0
              #  animationDefinition['stroke-dashoffset'].begin = 'anim' + (data.index - 1) + '.end'
              # We need to set an initial value before the animation starts as we are not in guided mode which would do that for us
              data.element.attr 'stroke-dashoffset': -pathLength + 'px'
              # We can't use guided mode as the animations need to rely on setting begin manually
              # See http://gionkunz.github.io/chartist-js/api-documentation.html#chartistsvg-function-animate
              data.element.animate animationDefinition, false
        ), 10
        setTimeout ( ->
          generateGraphLabels()
          moveChartLegend()
        ), 600
      return
    # get the most played role
    mostPlayedRole: ->
      roles = Session.get 'roleBreakdown'
      common = 'Marksman'
      for role of roles
        if roles[role] > roles[common]
          common = role
      return common
    #check for 'champion fit', if most played is in category w/most points
    championFit: ->
      roles = Session.get 'roleBreakdown'
      common = 'Marksman'
      for role of roles
        if roles[role] > roles[common]
          common = role
      pts = 0
      championId = '60'
      @latestChampionMastery.forEach (el) ->
        if el.championPoints > pts
          pts = el.championPoints
          championId = el.championId
      champion = Champions.findOne({championId: championId})
      if champion.championTags.indexOf(common) isnt -1
        return true
      return false
    #pull most played champ
    mostPlayedChampion: ->
      pts = 0
      championId = '60'
      @latestChampionMastery.forEach (el) ->
        if el.championPoints > pts
          pts = el.championPoints
          championId = el.championId
      champion = Champions.findOne({championId: championId})
      return champion.championName
    # and pull their tags
    mostMasteredRoles: ->
      pts = 0
      championId = '60'
      @latestChampionMastery.forEach (el) ->
        if el.championPoints > pts
          pts = el.championPoints
          championId = el.championId
      champion = Champions.findOne({championId: championId})
      return champion.championTags
    # get highest mastery value
    maxMastery: ->
      pts = 0
      @latestChampionMastery.forEach (el) ->
        if el.championPoints > pts
          pts = el.championPoints
          Session.set 'maxPts', pts
      return
    maxMasteryHumanLegible: ->
      pts = Session.get 'maxPts'
      return pts.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    totalMastery: ->
      pts = 0;
      @latestChampionMastery.forEach (el) ->
        pts += el.championPoints
      return pts
    totalMasteryHumanLegible: ->
      return Session.get 'rolesChartLabel'
    incrementTotalMasteryHumanLegible: ->
      pts = 0;
      @latestChampionMastery.forEach (el) ->
        pts += el.championPoints

      $(someValue: 0).animate { someValue: pts },
        duration: 500
        easing: 'swing'
        step: ->
          # called on every step
          # Update the element's text with rounded-up value:
          Session.set 'rolesChartLabel', Math.round(@someValue).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")
      return
    #set the champion mastery context
    championMastery: ->
      console.log @latestChampionMastery
      return @latestChampionMastery
    #get current champion level
    levels: ->
      max = Number(Session.get 'maxPts')
      max = Math.max(max, 21600)
      lvls = [0, 1800, 4200, 6600, 9000]
      lvls = lvls.map (num) -> Math.round (num/max * 100 )
      return lvls
    #get mastery points
    masteryPoints: ->
      points = @championPoints
      if (points > 21600)
        mp = points - 21600
      else
        mp = null
      return mp
    #or points until mastery
    pointsToMastery: ->
      points = @championPoints
      if (points < 21600)
        mp = 21600 - points
      else
        mp = null
      return mp
    # get prior role state
    currentRoleBreakdown: ->
      return Session.get 'currentRoleBreakdown'
    scopeIsRoles: ->
      chartScope = Session.get('chartScope')
      if chartScope is 'roles'
        return true
      return false
    scopeIsChampions: ->
      chartScope = Session.get('chartScope')
      if chartScope is 'champions'
        return true
      return false
    scopeIsChampion: ->
      chartScope = Session.get('chartScope')
      if chartScope is 'champion'
        return true
      return false
    #get relative mastery
    relativeMastery: ->
      relativeTo = Math.max(Number(Session.get 'maxPts'), 21600)
      percent = Math.round( @championPoints/relativeTo * 100 )
      return percent
    champion: ->
      champion = Champions.findOne({championId: @championId})
      return champion
    championName: ->
      return @championName

  Template.summonerSummary.events
    'click .toggle-legend': ->
      $('.chart__legend').toggleClass('active')
    'click .toggle-at-a-glance': ->
      $('.at-a-glance').toggleClass('active')
    'mouseover .ct-series': (e) ->
      $('.segment__label').removeClass('active')
      label = $(e.currentTarget).children('.ct-slice-donut').attr('ct:meta').replace('&#039;', "'")
      $('.segment__label[data-label="' + label + '"]').addClass('active')
    'click .return-to-roles': (e) ->
      Session.set Session.set 'loadingRolesBreakdown', Session.get('loadingRolesBreakdown') + 1
      Session.set 'chartScope', 'roles'
    'click .return-to-champions': (e) ->
      Session.set 'chartScope', 'champions'
      role = Session.get 'currentRoleBreakdown'
      summonerId = Number(FlowRouter.getParam('riotId'))
      Meteor.call 'updateBreakdown', ['toChampions', role, summonerId], (err, res) ->
        if err
          throw new Meteor.Error(err.name, err.message)
        else
          clearGraphLabels()
          $('.ct-chart').attr('data-scope', 'champions')
          Session.set 'chartScope', 'champions'
          Session.set 'currentRoleBreakdown', role
          data = res
          options =
            donut: true
            chartPadding: 30,
            labelOffset: 50,
            labelDirection: 'explode'
            plugins: [
              Chartist.plugins.legend({clickable: false})
            ]
          Session.set 'chart', data
          chart = (Chartist.Pie)('.ct-chart', data, options)
          chart.on 'draw', (data) ->
            if data.type == 'slice'
              # Get the total path length in order to use for dash array animation
              pathLength = data.element._node.getTotalLength()
              # Set a dasharray that matches the path length as prerequisite to animate dashoffset
              data.element.attr 'stroke-dasharray': pathLength + 'px ' + pathLength + 'px'
              # Create animation definition while also assigning an ID to the animation for later sync usage
              animationDefinition = 'stroke-dashoffset':
                id: 'anim' + data.index
                dur: 500
                from: -pathLength + 'px'
                to: '0px'
                fill: 'freeze'
              # HACK removing smooth animating circle in favor of all segments animating because I need animationend and haven't found it yet
              # If this was not the first slice, we need to time the animation so that it uses the end sync event of the previous animation
              #if data.index isnt 0
              #  animationDefinition['stroke-dashoffset'].begin = 'anim' + (data.index - 1) + '.end'
              # We need to set an initial value before the animation starts as we are not in guided mode which would do that for us
              data.element.attr 'stroke-dashoffset': -pathLength + 'px'
              # We can't use guided mode as the animations need to rely on setting begin manually
              # See http://gionkunz.github.io/chartist-js/api-documentation.html#chartistsvg-function-animate
              data.element.animate animationDefinition, false
          setTimeout ( ->
            generateGraphLabels()
            moveChartLegend()
          ), 600
    'click [data-scope="champions"] .ct-slice-donut': (e) ->
      champion = $(e.currentTarget).attr('ct:meta').replace('&#039;', "'")
      Session.set 'labelContext', champion
      summonerId = Number(FlowRouter.getParam('riotId'))
      Meteor.call 'updateBreakdown', ['toChampion', champion, summonerId], (err, res) ->
        if err
          throw new Meteor.Error(err.name, err.message)
        else
          clearGraphLabels()
          $('.ct-chart').attr('data-scope', 'champion')
          Session.set 'chartScope', 'champion'
          data = res
          options =
            donut: true
            chartPadding: 30,
            labelOffset: 50,
            labelDirection: 'explode'
            plugins: [
              Chartist.plugins.legend({clickable: false})
            ]
          Session.set 'chart', data
          chart = (Chartist.Pie)('.ct-chart', data, options)
          chart.on 'draw', (data) ->
            if data.type == 'slice'
              # Get the total path length in order to use for dash array animation
              pathLength = data.element._node.getTotalLength()
              # Set a dasharray that matches the path length as prerequisite to animate dashoffset
              data.element.attr 'stroke-dasharray': pathLength + 'px ' + pathLength + 'px'
              # Create animation definition while also assigning an ID to the animation for later sync usage
              animationDefinition = 'stroke-dashoffset':
                id: 'anim' + data.index
                dur: 500
                from: -pathLength + 'px'
                to: '0px'
                fill: 'freeze'
              # HACK removing smooth animating circle in favor of all segments animating because I need animationend and haven't found it yet
              # If this was not the first slice, we need to time the animation so that it uses the end sync event of the previous animation
              #if data.index isnt 0
              #  animationDefinition['stroke-dashoffset'].begin = 'anim' + (data.index - 1) + '.end'
              # We need to set an initial value before the animation starts as we are not in guided mode which would do that for us
              data.element.attr 'stroke-dashoffset': -pathLength + 'px'
              # We can't use guided mode as the animations need to rely on setting begin manually
              # See http://gionkunz.github.io/chartist-js/api-documentation.html#chartistsvg-function-animate
              data.element.animate animationDefinition, false
          setTimeout ( ->
            generateGraphLabels()
            moveChartLegend()
          ), 600
    'click [data-scope="roles"] .ct-slice-donut': (e) ->
      role = $(e.currentTarget).attr('ct:meta')
      summonerId = Number(FlowRouter.getParam('riotId'))
      Meteor.call 'updateBreakdown', ['toChampions', role, summonerId], (err, res) ->
        if err
          throw new Meteor.Error(err.name, err.message)
        else
          clearGraphLabels()
          $('.ct-chart').attr('data-scope', 'champions')
          Session.set 'chartScope', 'champions'
          Session.set 'currentRoleBreakdown', role
          data = res
          options =
            donut: true
            chartPadding: 30,
            labelOffset: 50,
            labelDirection: 'explode'
            plugins: [
              Chartist.plugins.legend({clickable: false})
            ]
          Session.set 'chart', data
          chart = (Chartist.Pie)('.ct-chart', data, options)
          chart.on 'draw', (data) ->
            if data.type == 'slice'
              # Get the total path length in order to use for dash array animation
              pathLength = data.element._node.getTotalLength()
              # Set a dasharray that matches the path length as prerequisite to animate dashoffset
              data.element.attr 'stroke-dasharray': pathLength + 'px ' + pathLength + 'px'
              # Create animation definition while also assigning an ID to the animation for later sync usage
              animationDefinition = 'stroke-dashoffset':
                id: 'anim' + data.index
                dur: 500
                from: -pathLength + 'px'
                to: '0px'
                fill: 'freeze'
              # HACK removing smooth animating circle in favor of all segments animating because I need animationend and haven't found it yet
              # If this was not the first slice, we need to time the animation so that it uses the end sync event of the previous animation
              #if data.index isnt 0
              #  animationDefinition['stroke-dashoffset'].begin = 'anim' + (data.index - 1) + '.end'
              # We need to set an initial value before the animation starts as we are not in guided mode which would do that for us
              data.element.attr 'stroke-dashoffset': -pathLength + 'px'
              # We can't use guided mode as the animations need to rely on setting begin manually
              # See http://gionkunz.github.io/chartist-js/api-documentation.html#chartistsvg-function-animate
              data.element.animate animationDefinition, false
          setTimeout ( ->
            generateGraphLabels()
            moveChartLegend()
          ), 600

  Template.homepage2.onRendered ->
    $('body').removeClass()
    $('body').addClass('admin-page')
  Template.homepage2.helpers
    counter: ->
      return Session.get 'counter'

  Template.homepage2.events
    'click .serverify-NA': (e) ->
      Meteor.call 'serverifyNA', {}, (err, res) ->
        if err
          throw new Meteor.Error(err.name, err.message)
        else
          console.log res
    'click .prune-matches': (e) ->
      Meteor.call 'pruneMatches', {}, (err, res) ->
        if err
          throw new Meteor.Error(err.name, err.message)
        else
          console.log res
    'click button': ->
      # increment the counter when button is clicked
      Session.set 'counter', Session.get('counter') + 1

    'submit #get-matches-of-summoner': (e) ->
      e.preventDefault()
      summId = $('[name="summoner-id"]').val()
      Meteor.call 'getMatchesOfSummoner', summId, (err, res) ->
        if err
          throw new Meteor.Error(err.name, err.message)
        else
          console.log res

    'submit #grab-summoner': (e) ->
      e.preventDefault()
      summName = $('[name="summoner-name"]').val()

      Meteor.call 'getSummoner', summName, (err, res) ->
        if err
          throw new Meteor.Error(err.name, err.message)
        else
          console.log res

    'submit #search-matches': (e) ->
      e.preventDefault()
      if $('[name="match-summoner"]').val().length
        summoner = $('[name="match-summoner"]').val()
      else
        summoner = null
      # Find the matches for this user
      Meteor.call 'getSummonerMatches', summoner, (err, res) ->
        if err
          throw new Meteor.Error(err.name, err.message)
        else
          console.log res

    'click #get-champion-masteries': ->
      Meteor.call 'getChampionMasteries', {}, (err, res) ->
        if err
          throw new Meteor.Error(err.name, err.message)
        else
          console.log res

    'click .matchify-summoners': ->
      Meteor.call 'matchifySummoners', {}, (err, res) ->
        if err
          throw new Meteor.Error(err.name, err.message)
        else
          console.log res

    'click #keyify-summoner': ->
      Meteor.call 'keyifySummoners', {}, (err, res) ->
        if err
          throw new Meteor.Error(err.name, err.message)
        else
          console.log res
