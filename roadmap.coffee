if Meteor.isClient
  Template.roadmap.onRendered ->
    $('body').removeClass()
    $('body').addClass('secretsgg-page')
