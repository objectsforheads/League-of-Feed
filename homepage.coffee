if Meteor.isClient
  Template.homepage.onRendered ->
    Session.set 'errorMessage', null
    $(document).ready ->
      # HACK server input will never exceed label length, so force the width
      $('#find-summoner__summoner-server').css 'width', $('label[for="find-summoner__summoner-server"]').width() * 1.5 + 'px'
      return
  Template.homepage.helpers
    isError: ->
      return Session.get 'errorMessage'
  Template.homepage.events
    # HACK there's probably a better way to do this
    # but lol look at the time it's not happening this round
    # toggle label position for summoner name
    'change #find-summoner__summoner-name, paste #find-summoner__summoner-name, keyup #find-summoner__summoner-name, focus #find-summoner__summoner-name, blur #find-summoner__summoner-name': (e) ->
      $input = $(e.currentTarget)
      $value = $input.val()
      if $value.length
        $input.removeClass('empty')
      else
        $input.addClass('empty')
    # interactions for choosing server
    # toggle button active state
    'click .input__server, click .server-selection': ->
      $('.server-selections').toggleClass('active')
    'click .server-selection': ->
      server = $('input[name="server"]:checked').val()
      $('#find-summoner__summoner-server').val(server).bind()
    # if typing in a server, enable buttons and match
    'change #find-summoner__summoner-server, paste #find-summoner__summoner-server, keyup #find-summoner__summoner-server': (e) ->
      servers = ['NA', 'BR', 'EUNE', 'EUW', 'JP', 'KR', 'LAN', 'LAS', 'OCE', 'RU', 'TR']
      $input = $(e.currentTarget)
      $value = $input.val().toUpperCase()
      $('[name="server"]').prop 'checked', false
      # if correct server, enable it
      if servers.indexOf($value) isnt -1
        $('[name="server"][value="' + $value + '"]').prop('checked', true)
        $('#find-summoner__summoner-server').blur()
        # delay button hide so user sees button pressed
        setTimeout ( ->
          $('.server-selections').removeClass('active')
        ), 350
    'submit #intro__find-summoner': (e) ->
      e.preventDefault()
      Session.set 'errorMessage', null
      # HACK stripping out any potentially malicious tags
      # ideally, we whitelist all possible characters but I haven't figured
      # out everything that's allowed yet
      name = $('#find-summoner__summoner-name').val().replace(/(<([^>]+)>)/ig,"")
      servers = ['NA', 'BR', 'EUNE', 'EUW', 'JP', 'KR', 'LAN', 'LAS', 'OCE', 'RU', 'TR']
      server = $('#find-summoner__summoner-server').val().toUpperCase()
      # make sure server is a valid one
      if servers.indexOf(server) is -1
        server = false
      if name and server
        server = server.toLowerCase()
        # set communicating w/server state
        # transition to loading screen
        $('.screen--intro').fadeOut '300ms', ->
          $('.screen--intro').hide()
          # slight delay for experience
          setTimeout (->
            $('.screen--loading-summoner').fadeIn()
            return
          ), 150
          return
        $('#intro__find-summoner button[type="submit"]').prop('disabled', true)
        Meteor.call 'findSummoner', [name, server], (err, res) ->
          if err
            Session.set 'errorMessage', 'Summoner doesn\'t exist! Try another server, check your spelling, or look for another summoner.'
            #reset state
            # transition to loading screen
            $('.screen--loading-summoner').fadeOut '300ms', ->
              $('.screen--loading-summoner').hide()
              # slight delay for experience
              setTimeout (->
                $('.screen--intro').fadeIn()
                return
              ), 150
              return
            $('#intro__find-summoner button[type="submit"]').prop('disabled', false)
          else
            FlowRouter.go('/summoner/' + res[1] + '/' + res[0])
      else
        if !name
          Session.set 'errorMessage', 'Huh. Something\'s up with the summoner name. We suspect it\'s the lack of one.'
        else if !server
          Session.set 'errorMessage', 'Whoa there! That server doesn\'t exist. You\'re free to type out the server shorthand, but those buttons work pretty well too.'
