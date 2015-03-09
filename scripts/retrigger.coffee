jenkingHost = process.env['JENKINGD_HOST'] || 'http://10.0.101.226:8777'
module.exports = (robot) ->

  robot.hear /^jobstatus\s+(\S+)\s+(\d+)/, (msg) ->
    msg.send "Getting job status for #{msg.match[1]} #{msg.match[2]}"
    jobStatus msg, msg.match[1], msg.match[2], (url) ->
      msg.send url

  jobStatus = (msg) ->
    robot.http("#{jenkingHost}/jobstatus/?text=#{msg.match[1].trim()}%20#{msg.match[2]}")
      .get() (err, res, body) ->
        msg.send body

  robot.hear /^retrigger\s+(\S+)\s+(\d+)/, (msg) ->
    msg.send "Retriggering Job: #{msg.match[1]} Patchset #: #{msg.match[2]}"
    retriggerJob msg, msg.match[1], msg.match[2], (url) ->
      msg.send url

  retriggerJob = (msg) ->
    robot.http("#{jenkingHost}/slack/?text=#{msg.match[1].trim()}%20#{msg.match[2]}")
      .get() (err, res, body) ->
        msg.send body
