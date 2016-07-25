cp = require "child_process"

jenkingHost = process.env['JENKINGD_HOST'] || 'http://10.0.101.226:8777'
gerritHost = process.env['GERRIT_HOST'] || 'gerrit.instructure.com'
gerritPort = process.env['GERRIT_PORT'] || 29418

module.exports = (robot) ->

  robot.hear /^~jobStatus\s+(\S+)\s+(\d+)/, (msg) ->
    msg.send "Getting job status for #{msg.match[1]} #{msg.match[2]}"
    jobStatus msg, msg.match[1], msg.match[2], (url) ->
      msg.send url

  jobStatus = (msg) ->
    robot.http("#{jenkingHost}/jobstatus/?text=#{msg.match[1].trim()}%20#{msg.match[2]}")
      .get() (err, res, body) ->
        msg.send body

  robot.hear /^~retriggerJenkins\s+(\S+)\s+(\d+)/, (msg) ->
    msg.send "Retriggering Job: #{msg.match[1]} Patchset #: #{msg.match[2]}"
    retriggerJob msg, msg.match[1], msg.match[2], (url) ->
      msg.send url

  retriggerJob = (msg, jobName, jobNumber) ->
    robot.http("#{jenkingHost}/slack/?text=#{jobName.trim()}%20#{jobNumber}")
      .get() (err, res, body) ->
        msg.send body

  robot.hear /^~retrigger\s+(\S+)/, (msg) ->
    rawChangeParam = msg.match[1]
    linkChangeRegex = new RegExp(gerritHost + "\/(\\d+)")
    if rawChangeParam.match(/^\d+$/)
      retriggerAllForGerrit msg, rawChangeParam
    else if matchData = linkChangeRegex.exec(rawChangeParam)
      retriggerAllForGerrit msg, matchData[1]
    else
      msg.send("Invalid change number. Example usage:\n" +
                "~retrigger 12345\n" +
                "~retrigger #{gerritHost}/12345")

  # jenkins or jenking throttles requests
  delayedRetrigger = (msg, jobName, jobNumber, delay) ->
    setTimeout ->
      msg.send "Retriggering Job: #{jobName}/#{jobNumber}"
      retriggerJob(msg, jobName, jobNumber)
    , delay

  retriggerAllForGerrit = (msg, changeNumber) ->
    cp.exec "ssh #{gerritHost} -p #{gerritPort} gerrit query --format=JSON --comments --current-patch-set #{changeNumber}", (err, stdout, stderr) ->
      if err
        msg.send "Sorry, something went wrong talking with Gerrit: #{stderr}"
        return

      results = (JSON.parse l for l in stdout.split "\n" when l isnt "")
      if results.length == 0 || !results[0].comments
        msg.send "Sorry, change #{changeNumber} can't be found"
        return

      failed_comments = results[0].comments.filter (c) ->
        c.reviewer.name == "Jenkins" &&
          c.message.match(/Build Failed/i)

      if failed_comments.length == 0
        msg.send "No failed comments from Jenkins can be found for Gerrit change: #{changeNumber}"
        return

      failed_comment_msg = failed_comments[failed_comments.length-1].message
      failure_lines = failed_comment_msg.split("\n").filter (line) -> line.match(/(FAILURE|ABORTED)/)
      for failure_line, i in failure_lines
        # http://jenkins.example.com/job/some-job/123/
        matchData = /\/job\/(.*)\/(.*)\//.exec(failure_line)
        delayedRetrigger(msg, matchData[1], matchData[2], i * 200)
