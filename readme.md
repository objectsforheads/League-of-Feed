# League of Feed
Developed for the 2016 Riot API Challenge, League of Feed hoards your champion mastery data, along with some other exposed data points, to make pretty aggregate graphs.

It also uses some math to recommend a new champion for you to <strike>feed with</strike> have fun with, based on what champions people with similar champion masteries to you tend to play.

League of Feed was originally intended to fulfill the following purposes:
 - be a personal and friend 'feed' that tracked your champion mastery accrual as well as that of the people you followed
 - provide leaderboards on both a local and server-wide scale
 - use aggregate data to predict champions you might want to play
It currently does exactly one of these things, but we're keeping the name as a fond homage to the philosophy of an eternally salty Silver I player. True to form, League of Feed too strives to <strike>make it to the promised land of Gold V</strike> fulfill its original goals, if only their <strike>team</strike> developer wasn't so hard to carry.

# Live
League of Feed currently lives [here], for as long as we can keep the servers going. Otherwise, the source code is available here on github, which you can pull and then use to hoard your own databases.

## Demoing
League of Feed features two main actions:
 - search for summoners
 - explore summoner aggregate data

### Searching
To start using League of Feed, search for a summoner by name and server.

### Exploring
League of Feed breaks down aggregate champion mastery data into `Champion Tags`, which it considers analogous to that summoner's preferred champion type. From there, the graph drills down into `Champions` within the `Champion Tag` and then what `Lanes` you tend to play that `Champion` in. It also provides some nifty number breakdowns and conclusions which you can explore by toggling the `Stats` icon. This side menu also has the summoner's `Recommended Champion`.

To see an overview of a summoner's masteries, you can click the `graph` icon by the summoner's name. That pulls up every single champion that the summoner has accrued champion mastery points for. At that point, you can filter based on `Champion Tag`. Clicking on the `Pie Chart` icon will bring up some conclusions that League of Feed has studiously crunched numbers to get to for you to see.

# Data
League of Feed collects a lot of data and then also throws away a lot of data. Because databases are expensive to maintain. Some of the more interesting methodologies are listed here for your curiosity. Feel free to optimize as you see fit, then let us know!

## Calling the API
All API calls are routed through Meteor's server, which is assumed (by Meteor and us) to be secure. The client calls the `Meteor.method` from the server, which then returns the result of the call to the client. The API key is kept in `settings.json` and only exists server-side.

## Collecting Summoners
To gather a lot of summoners (so that we can aggregate their data), we:
 1. pull a 'seed' summoner's `id` by querying the `summoner` API with their `summonerName` and `server`
   1. we keep track of summoners through their `id` and their `summonerName`, which we store both as-is from the API, and in a normalized `key` for ease of search and access
 2. query the `matchlist` API with the summoner `id` and pull back every `matchId`
 3. query the `match` API with each `matchId` to get `participantIdentities`, storing them in our `Summoners` database
 4. query the relevant APIs to get user data. League of Feed uses `championmastery` and `match`
   1. these processes run independently, so as to not run into API limits. Getting all the `summoner` information is a separate request to the server to find all summoners missing fields and then querying the API for them

Once a summoners has been used as a seed, their return of new summoners per API call diminishes substantially. We mark these summoners as `polled: true` so that whenever we pull a new seed summoner, it won't be an exhausted seed.

## Recommending a Champion
The champion recommendation is based on a comparison between the summoner's data breakdown and other summoners with similar breakdowns. In its current rendition, League of Feed's formula for comparison isn't particularly adaptive. League of Feed assumes that the type of champion you prefer to play, the `Champion Tag`, is the most important factor in determining 'champion fit'. It looks for other users with a similar percent breakdown and collates them. Then, it looks at the *cumulative* champion mastery and sorts out the highest mastery. In more detail:

  1. Collects the summoner's champion preferences as an array of objects that reflect the percent breakdown of each `Champion Tag`
  2. Finds other users with +/- similar percentages, filtering from the highest (eg. pull 500 summoners with a similar top percent of `Champion Tag`) to the lowest (eg. from these 500, then pull 100 summoners with a similar 2nd top percent of `Champion Tag`)
  3. From this filtered set of summoners, aggregate champion mastery as an *average of relative mastery*
  4. Return the champion with the highest average mastery that the summoner *has not yet mastered*

# Technologies & Running Your Own League of Feed
League of Feed is built on Meteor 1.2.1. To build League of Feed locally, install Meteor and pull League of Feed's files from github. You will need a `settings.json` file:

```
{
  "riotApiKey": "secretKey"
}
```

Run League of Feed by `cd`ing to the folder with League of Feed and running `meteor --settings /PATH/TO/settings.json`. If you haven't specified a port through `--port`, Meteor defaults to `3000`. You should be able to see your local copy of League of Feed at `localhost:3000`.

Admin functions are located at `/admin`. You can use these functions to bulk add/modify data to your database.

League of Feed also employs Chartist to generate its charts, Velocity.js for complex animations, and Google Fonts/Typekit for its typography.

# Roadmap
League of Feed is _incredibly_ unfinished. In fact, a stop on the roadmap is to write out a more coherent roadmap.

Some housekeeping things to do:
- set up error management
- DRY/refactor some of the code
- consider migrating to Meteor 1.3
- look into self-hosting a MongoDB on DigitalOcean or similar
- fix up some of the hacks
- figure out scaling (we can't call 600k data points on each graph)
  - or can we (if we queue)
- speaking of, set up a queue to collect data on a schedule

Some functionality to add:
 - user accounts
 - verify summoners
 - follow people and mutually friend/be friended
 - track avg mastery gain and project time to mastery
 - leaderboards
 - higher fidelity data/more ways to visualize data
 - ability to compare data between summoners/to aggregate/etc

Some odd things I would like to do:
 - write a nicer, user-friendly looking, roadmap and link it to `/secretsgg`
 - rename all my methods to use `rito` instead of `riot`
