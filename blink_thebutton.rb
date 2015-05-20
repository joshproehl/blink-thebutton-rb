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
    return [229, 0, 0]
  when 11..20
    return [229, 149, 0]
  when 21..30
    return [229, 217, 0]
  when 31..40
    return [2, 190, 1]
  when 41..50
    return [0, 50, 199]
  when 51..60
    return [130, 0, 128]
  else
    return [255, 255, 255]
  end
end


def fadeLightForButtonSeconds(light, seconds)
  color = rgbForSeconds(seconds)
  light.fade_to_rgb(2000, color[0], color[1], color[2])
end


def setLifx(seconds)
  color = rgbForSeconds(seconds)

  auth = {:username => LIFX_TOKEN, :password => ""}
  data = "color=rgb:#{color[0]},#{color[1]},#{color[2]}"

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

  fadeLightForButtonSeconds(b, 0)

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

      fadeLightForButtonSeconds(b, seconds_left)

      if(LIFX_TOKEN != "" && LIFX_IDENTIFIER != "")
        setLifx(seconds_left)
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
