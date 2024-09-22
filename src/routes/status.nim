# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, strutils, sequtils, uri, options, sugar

import jester, karax/vdom

import router_utils
import ".."/[types, formatters, api]
import ../views/[general, status, search]

export uri, sequtils, options, sugar
export router_utils
export api, formatters
export status

proc createStatusRouter*(cfg: Config) =
  router status:
    get "/@name/status/@id/@reactors":
      cond '.' notin @"name"
      let id = @"id"

      if id.len > 19 or id.any(c => not c.isDigit):
        resp Http404, showError("Invalid tweet ID", cfg)

      let prefs = cookiePrefs()

      # used for the infinite scroll feature
      if @"scroll".len > 0:
        let replies = await getReplies(id, getCursor())
        if replies.content.len == 0:
          resp Http404, ""
        resp $renderReplies(replies, prefs, getPath())

      if @"reactors" == "favoriters":
        resp renderMain(renderUserList(await getGraphFavoriters(id, getCursor()), prefs),
                        request, cfg, prefs)
      elif @"reactors" == "retweeters":
        resp renderMain(renderUserList(await getGraphRetweeters(id, getCursor()), prefs),
                        request, cfg, prefs)

    get "/@name/status/@id/?":
      cond '.' notin @"name"
      let id = @"id"

      if id.len > 19 or id.any(c => not c.isDigit):
        resp Http404, showError("Invalid tweet ID", cfg)

      let prefs = cookiePrefs()

      # used for the infinite scroll feature
      if @"scroll".len > 0:
        let replies = await getReplies(id, getCursor())
        if replies.content.len == 0:
          resp Http404, ""
        resp $renderReplies(replies, prefs, getPath())

      let conv = await getTweet(id, getCursor())
      if conv == nil:
        echo "nil conv"

      if conv == nil or conv.tweet == nil or conv.tweet.id == 0:
        var error = "Tweet not found"
        if conv != nil and conv.tweet != nil and conv.tweet.tombstone.len > 0:
          error = conv.tweet.tombstone
        resp Http404, showError(error, cfg)

      let
        title = pageTitle(conv.tweet)
        ogTitle = pageTitle(conv.tweet.user)
        desc = conv.tweet.text

      var
        images = conv.tweet.photos
        video = ""

      if conv.tweet.video.isSome():
        let videoObj = get(conv.tweet.video)
        images = @[videoObj.thumb]

        let vars = videoObj.variants.filterIt(it.contentType == mp4)
        # idk why this wont sort when it sorts everywhere else
        #video = vars.sortedByIt(it.bitrate)[^1].url
        video = vars[^1].url
      elif conv.tweet.gif.isSome():
        let gif = get(conv.tweet.gif)
        images = @[gif.thumb]
        video = getPicUrl(gif.url)
      elif conv.tweet.card.isSome():
        let card = conv.tweet.card.get()
        if card.image.len > 0:
          images = @[card.image]
        elif card.video.isSome():
          images = @[card.video.get().thumb]

      let html = renderConversation(conv, prefs, getPath() & "#m")
      resp renderMain(html, request, cfg, prefs, title, desc, ogTitle,
                      images=images, video=video)

    get "/@name/@s/@id/@m/?@i?":
      cond @"s" in ["status", "statuses"]
      cond @"m" in ["video", "photo"]
      redirect("/$1/status/$2" % [@"name", @"id"])

    get "/@name/statuses/@id/?":
      redirect("/$1/status/$2" % [@"name", @"id"])

    get "/i/web/status/@id":
      redirect("/i/status/" & @"id")
      
    get "/@name/thread/@id/?":
      redirect("/$1/status/$2" % [@"name", @"id"])
