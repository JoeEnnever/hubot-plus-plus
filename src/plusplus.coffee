# Description:
#   Give or take away points. Keeps track and even prints out graphs.
#
# Dependencies:
#   "underscore": ">= 1.0.0"
#   "clark": "0.0.6"
#
# Configuration:
#
# Commands:
#   <name>++
#   <name>--
#   hubot score <name> [for <reason>]
#   hubot top <amount>
#   hubot bottom <amount>
#   hubot erase <user> [<reason>]
#
# URLs:
#   /hubot/scores[?name=<name>][&direction=<top|botton>][&limit=<10>]
#
# Author:
#   ajacksified


_ = require('underscore')
clark = require('clark')
querystring = require('querystring')
ScoreKeeper = require('./scorekeeper')
SlackBotMessage = require('hubot-slack').SlackBotMessage

module.exports = (robot) ->
  scoreKeeper = new ScoreKeeper(robot)

  # sweet regex bro
  robot.hear ///
    # from beginning of line
    ^
    # the thing being upvoted, which is any number of words and spaces
    ([\s\w'@.\-:]*||c\+\+)
    # allow for spaces after the thing being upvoted (@user ++)
    \s*
    # the increment/decrement operator ++ or --
    ([-+]{2}|—)
    # optional reason for the plusplus
    (?:\s+(?:for|because|cause|cuz)\s+(.+))?
    $ # end of line
  ///i, (msg) ->
    # let's get our local vars in place
    [dummy, name, operator, reason] = msg.match
    from = msg.message.user.name.toLowerCase()
    room = msg.message.room

    if msg.message.user.slack.is_bot
      msg.reply "Bots don't have the right to vote"
      return

    # do some sanitizing
    reason = reason?.trim().toLowerCase()

    if name
      if name.charAt(0) == ":"
        name = (name.replace /(^\s*@)|([,\s]*$)/g, '').trim().toLowerCase()
      else
        name = (name.replace /(^\s*@)|([,:\s]*$)/g, '').trim().toLowerCase()

    # check whether a name was specified. use MRU if not
    unless name? && name != ''
      [name, lastReason] = scoreKeeper.last(room)
      reason = lastReason if !reason? && lastReason?

    if (name == 'c++' || name == 'cplusplus') && operator == "++"
      msg.reply "Sorry, you can't upvote #{name}. Only downvote"
      return

    if (name == 'vijay')
      msg.send "https://cdn.meme.am/instances/500x/67985421.jpg"
      return

    # do the {up, down}vote, and figure out what the new score is
    [score, reasonScore] = if operator == "++"
              scoreKeeper.add(name, from, room, reason)
            else
              scoreKeeper.subtract(name, from, room, reason)

    # if we got a score, then display all the things and fire off events!
    if score?
      message = if reason?
                  if reasonScore == 1 or reasonScore == -1
                    "#{name} has #{score} points, #{reasonScore} of which is for #{reason}."
                  else
                    "#{name} has #{score} points, #{reasonScore} of which are for #{reason}."
                else
                  if score == 1
                    "#{name} has #{score} point"
                  else
                    "#{name} has #{score} points"

      msg.send message
      if score == -100 && !scoreKeeper.celebrated100(name)
        setTimeout(() =>
          msg.send "YOU DID IT VIJAY!"
          msg.send "https://media.giphy.com/media/YYD3fLEOdcOv6/giphy.gif"
        , 2000)
        setTimeout(() =>
          msg.send "YOU MADE IT!"
          msg.send "https://media.giphy.com/media/84DhLtzE33YvS/giphy.gif"
        , 4000)
        setTimeout(() =>
          msg.send "TODAY IS YOUR DAY!"
          msg.send "https://media.giphy.com/media/4SjSCUMhuAcda/giphy.gif"
        , 6000)
        setTimeout(() =>
          msg.send "@here VIJAY HIT -100!"
          msg.send "https://media.giphy.com/media/zaDi0mXkYM3eg/giphy.gif"
        , 8000)
        setTimeout(() =>
          msg.send "@here END OF AN ERA! CELEBRATION IN THE ENG ROOM"
          msg.send "https://media.giphy.com/media/zAQzMspkNl2Ao/giphy.gif"
        , 10000)

      robot.emit "plus-one", {
        name:      name
        direction: operator
        room:      room
        reason:    reason
        from:      from
      }

  robot.respond ///
    (?:erase )
    # thing to be erased
    ([\s\w'@.-:]+?)
    # optionally erase a reason from thing
    (?:\s+(?:for|because|cause|cuz)\s+(.+))?
    $ # eol
  ///i, (msg) ->
    msg.reply "No more erase, blame @vijay"
    return
    [__, name, reason] = msg.match
    from = msg.message.user.name.toLowerCase()
    user = msg.envelope.user
    room = msg.message.room
    reason = reason?.trim().toLowerCase()

    if name
      if name.charAt(0) == ":"
        name = (name.replace /(^\s*@)|([,\s]*$)/g, "").trim().toLowerCase()
      else
        name = (name.replace /(^\s*@)|([,:\s]*$)/g, "").trim().toLowerCase()

    isAdmin = @robot.auth?.hasRole(user, 'plusplus-admin') or @robot.auth?.hasRole(user, 'admin')

    if not @robot.auth? or isAdmin
      erased = scoreKeeper.erase(name, from, room, reason)
    else
      return msg.reply "Sorry, you don't have authorization to do that."

    if erased?
      message = if reason?
                  "Erased the following reason from #{name}: #{reason}"
                else
                  "Erased points for #{name}"
      msg.send message

  robot.respond /score (for\s)?(.*)/i, (msg) ->
    name = msg.match[2].trim().toLowerCase()
    score = scoreKeeper.scoreForUser(name)
    reasons = scoreKeeper.reasonsForUser(name)
    pointWord = if score == 1 then "point" else "points"
    reasonString = if typeof reasons == 'object' && Object.keys(reasons).length > 0
                     "#{name} has #{score} #{pointWord}. here are some raisins:" +
                     _.reduce(reasons, (memo, val, key) ->
                       otherPointWord = if val == 1 then "point" else "points"
                       memo += "\n#{key}: #{val} #{otherPointWord}"
                     , "")
                   else
                     "#{name} has #{score} #{pointWord}."

    msg.send reasonString

  robot.respond /rap sheet (for\s)?(.*)/i, (msg) ->
    name = msg.match[2].trim().toLowerCase()
    score = scoreKeeper.scoreForUser(name)
    reasons = scoreKeeper.reasonsForUser(name)
    pointWord = if score == 1 then "point" else "points"
    reasonString = if typeof reasons == 'object' && Object.keys(reasons).length > 0
                     "#{name} has #{score} #{pointWord}. here are some raisins:" +
                     _.reduce(reasons, (memo, val, key) ->
                       if val < 0
                         memo += "\n#{key}: #{val} points"
                       else
                         memo += ""
                     , "")
                   else
                     "#{name} has #{score} #{pointWord}."

    msg.send reasonString

  robot.respond /(top|bottom) (\d+)/i, (msg) ->
    amount = parseInt(msg.match[2]) || 10
    message = []

    tops = scoreKeeper[msg.match[1]](amount)

    if tops.length > 0
      for i in [0..tops.length-1]
        message.push("#{i+1}. #{tops[i].name} : #{tops[i].score}")
    else
      message.push("No scores to keep track of yet!")

    if(msg.match[1] == "top")
      graphSize = Math.min(tops.length, Math.min(amount, 20))
      message.splice(0, 0, clark(_.first(_.pluck(tops, "score"), graphSize)))

    msg.send message.join("\n")

  robot.router.get "/#{robot.name}/normalize-points", (req, res) ->
    scoreKeeper.normalize((score) ->
      if score > 0
        score = score - Math.ceil(score / 10)
      else if score < 0
        score = score - Math.floor(score / 10)

      score
    )

    res.end JSON.stringify('done')

  robot.router.get "/#{robot.name}/scores", (req, res) ->
    query = querystring.parse(req._parsedUrl.query)

    if query.name
      obj = {}
      obj['reasons'] = scoreKeeper.reasonsForUser(query.name)
      obj[query.name] = scoreKeeper.scoreForUser(query.name)
      res.end JSON.stringify(obj)
    else
      direction = query.direction || "top"
      amount = query.limit || 10

      tops = scoreKeeper[direction](amount)

      res.end JSON.stringify(tops, null, 2)
