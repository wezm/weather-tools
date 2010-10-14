--[[
# Copyright (c) 2010 Wesley Moore http://www.wezm.net/
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
]]

local mongrel2 = require 'mongrel2'
local json     = require 'json'
local sqlite   = require 'lsqlite3'
local waether  = require 'weather'

local sender_id = 'AA40D395-4CA6-47CD-9D8C-FD4FDF92487E'
local sub_addr = 'tcp://127.0.0.1:7777'
local pub_addr = 'tcp://127.0.0.1:7778'
local io_threads = 1
local db_path = arg[1]

if(not db_path) then
  print "Usage: weather db_path"
  os.exit(2)
end

local db = sqlite.open(db_path)

-- Create new mongrel2 context
local ctx = mongrel2.new(io_threads)

-- Creates a new connection object using the mongrel2 context
local conn = ctx:new_connection(sender_id, sub_addr, pub_addr)

local w = weather.new(db)

-- Enter the main loop
while true do
    print 'Waiting for request...'
    local req = conn:recv()

    if req:is_disconnect() then
        print 'Disconnected'
    else
        -- Dispatch
        -- print(req.path)
        local response
        local code = 200
        local status = "OK"
        local headers = {
          ["Content-Type"] = "text/plain"
        }

        if(req.path:find('^/weather/current')) then
          response = w:current()
          headers["Content-Type"] = "application/json"
        elseif(req.path:find('^/weather/history')) then
          response = w:history()
          headers["Content-Type"] = "application/json"
        else
          code = 404
          status = "Not Found"
          response = {error = status}
          headers["Content-Type"] = "application/json"
        end

        conn:reply_http(req, json.encode(response), code, status, headers)
    end
end

ctx:term()

