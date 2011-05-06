--[[
# Copyright (c) 2011 Wesley Moore http://www.wezm.net/
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

local setmetatable = setmetatable
local math = require "math"
local next = next

module 'weather'

local meta = {}
meta.__index = meta

function meta:current()
  -- Current Weather Conditions
  local sql = [[
      SELECT
        strftime("%s", datetime) * 1000 AS timestamp,
        dewpoint,
        forecast,
        rain_1h,
        rain_24h,
        rain_total,
        rel_humidity_in,
        rel_humidity_out,
        rel_pressure,
        temperature_in,
        temperature_out,
        tendency,
        wind_angle,
        wind_chill,
        wind_direction,
        wind_speed
      FROM weather
      WHERE datetime(datetime) = (
          SELECT MAX(datetime(datetime))
          FROM weather
      )
  ]]

  local weather = {}
  for row in self.db:nrows(sql) do
    weather = row
  end

  return weather
end

function meta:differential(x1, y1, x2, y2)
  local dt = (x2 - x1) / 1000 -- make the time unit seconds
  local dy = (y2) - (y1)
  return dy / dt
end

function meta:history()
  -- Weather History
  local sql = [[
      SELECT strftime("%s", datetime) * 1000 AS timestamp, temperature_in, temperature_out
      FROM weather
      WHERE temperature_out > -29.9 AND temperature_out < 69.9
      AND datetime > datetime('now', '-7 days')
  ]]

  local prev = nil
  local history = {}
  for row in self.db:nrows(sql) do
    if prev == nil then
      prev = row
    else
      local dydt_out = self:differential(
        prev.timestamp,
        prev.temperature_out,
        row.timestamp,
        row.temperature_out
      )

      local dydt_in = self:differential(
        prev.timestamp,
        prev.temperature_in,
        row.timestamp,
        row.temperature_in
      )

      if math.abs(dydt_in) < 0.01 and math.abs(dydt_out) < 0.01 then
        history[#history + 1] = {row.timestamp, row.temperature_in, row.temperature_out}
        prev = row
      end
    end
  end

  return history
end

-- Min Temperature
function meta:min()
  local sql = [[
    SELECT strftime("%s", datetime) * 1000 AS timestamp, temperature_out
    FROM weather
    WHERE date(datetime) = (SELECT MAX(date(datetime)) FROM weather)
    AND temperature_out > -29.9 AND temperature_out < 69.9
    ORDER BY temperature_out ASC
    LIMIT 1
  ]]

  local weather
  for row in self.db:nrows(sql) do
    weather = {
      temperature = row.temperature_out,
      timestamp = row.timestamp
    }
  end

  return weather
end

function meta:max()
  -- Max Temperature
  sql = [[
    SELECT strftime("%s", datetime) * 1000 AS timestamp, temperature_out
    FROM weather
    WHERE date(datetime) = (SELECT MAX(date(datetime)) FROM weather)
    AND temperature_out > -29.9 AND temperature_out < 69.9
    ORDER BY temperature_out DESC
    LIMIT 1
  ]]

  local weather
  for row in self.db:nrows(sql) do
    weather = {
      temperature = row.temperature_out,
      timestamp = row.timestamp
    }
  end

  return weather
end

-- Rainfall over the preceeding 7 days
function meta:rainfall_history()
  sql = [[
    SELECT date(datetime) AS date, rain_24h
    FROM weather
    WHERE date(datetime, 'localtime') <= date('now', 'localtime')
    GROUP BY date(datetime) HAVING datetime = MAX(datetime)
    ORDER BY datetime DESC LIMIT 7
  ]]


  rain = {}
  for row in self.db:nrows(sql) do
      rain[#rain + 1] = { row.date, row.rain_24h }
  end

  return rain
end

-- Rainfall for the current day (by hour)
function meta:rainfall_today()
  sql = [[
    SELECT strftime("%H", datetime) AS hour, rain_1h
    FROM weather
    WHERE date(datetime, 'localtime') == date('now', 'localtime')
    GROUP BY strftime("%Y-%m-%d %H", datetime) HAVING datetime = MAX(datetime)
    ORDER BY datetime ASC
  ]]

  rain = {}
  for row in self.db:nrows(sql) do
      rain[#rain + 1] = { row.hour, row.rain_1h }
  end

  return rain
end

function new(db)
    local obj = {
        db = db
    }

    return setmetatable(obj, meta)
end
