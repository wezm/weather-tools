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

local sqlite    = require "lsqlite3"
local json      = require "json"
local weatherdb = require "weather"

local db_path = arg[1]
local json_path = arg[2]

if(not(db_path and json_path)) then
  print("Usage: json2300 db_path json_path")
  os.exit(2)
end

local db = sqlite3.open(db_path)
local weather = weatherdb.new(db)

local data = {}
data.current = weather:current()
data.history = weather:history()
data.current.min = weather:min()
data.current.max = weather:max()

db:close()

-- write out JSON
local jsonfile, err = io.open(json_path, "w")
if (jsonfile) then
  jsonfile:write(json.encode(data))
  jsonfile:close()
else
  print("Unable to open JSON file for writing: " .. err)
end
