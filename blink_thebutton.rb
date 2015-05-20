#!/usr/bin/env ruby

require 'blink1'
require 'httparty'
require 'uri'
require 'websocket-client-simple'
require 'json'

LIFX_TOKEN = "" # Set your LIFX Api token here
LIFX_IDENTIFIER = "" # Set the identifier of the bulb you want to use. "label:Desk" for example


# RGB Values blatantly stolen from http://github.com/nattress/thebutton-hue/blob/master/server.js
def rgbForSeconds(s)
  case s
  when 1..10
    return {r: 229, g: 0, b: 0}
  when 11..20
    return {r: 229, g: 149, b: 0}
  when 21..30
    return {r: 229, g: 217, b: 0}
  when 31..40
    return {r: 2, g: 190, b: 1}
  when 41..50
    return {r: 0, g: 50, b: 199}
  when 51..60
    return {r: 130, g: 0, b: 128}
  else
    return {r: 255, g: 255, b: 255}
  end
end


def fadeButtonTo(light, color)
  light.fade_to_rgb(2000, color[:r], color[:g], color[:b])
end


def setLifx(color)
  auth = {:username => LIFX_TOKEN, :password => ""}
  data = "color=rgb:#{color[:r]},#{color[:g]},#{color[:b]}"

  begin
    putRes = HTTParty.put("https://api.lifx.com/v1beta1/lights/#{URI::escape(LIFX_IDENTIFIER)}/color", :body => data, :basic_auth => auth)
  rescue Exception => e
    puts e
  end

  return putRes.code
end


begin
  puts "Press Ctrl-C to exit."

  # Make sure our printing later gets writter immediately
  STDOUT.sync = true

  b = Blink1.new
  b.open

  rgb = rgbForSeconds(0)

  fadeButtonTo(b, rgb)

  response = HTTParty.get('http://cors-unblocker.herokuapp.com/get?url='+URI::escape("https://reddit.com/r/thebutton"))

  # Initial URL blatantly stolen from http://github.com/nattress/thebutton-hue/blob/master/server.js
  # I'm not entirely certain what the initial URL is doing actually, and I don't think it's ever used.
  # wsurl = "wss://wss.redditmedia.com/thebutton?h=7f66bf82878e6151f7688ead7085eb63a0baff0b?e=1428621271"

  if response.code == 200
    wsurl = /(wss:\/\/wss\.redditmedia\.com\/thebutton\?h=[^"]*)"/.match(response.body)[1]

    puts "Connecting to websocket: "+wsurl

    ws = WebSocket::Client::Simple.connect wsurl

    ws.on :message do |msg|
      parsedMsg = JSON.parse(msg.data)
      seconds_left = parsedMsg["payload"]["seconds_left"] - 1 # We're removing one to stay synced with what the website shows

      print "    Current tick: #{seconds_left}             "
      print "\r"

      newRgb = rgbForSeconds(seconds_left)

      # Only update the color if the new color is actually different
      # TODO: This is broken because [1,2,3] - [3,2,1] is empty, which makes it an invaled comparison
      if rgb != newRgb
        fadeButtonTo(b, newRgb)

        if(LIFX_TOKEN != "" && LIFX_IDENTIFIER != "")
          setLifx(newRgb)
        end

        rgb = newRgb
      end
    end

    loop do
      ws.send STDIN.gets.strip
    end
  end
rescue Interrupt
  print "                                                                    \r"
  b.off
  b.close
  puts "All done."
end
