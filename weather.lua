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

local setmetatable = setmetatable

module 'weather'

local meta = {}
meta.__index = meta

function meta:current()
  -- Current Weather Conditions
  local weather = {}

  self.current_stmt:reset()

  for row in self.current_stmt:nrows() do
    weather = row
  end

  --stmt:finalize()
  return weather
end

function meta:history()
  -- Weather History
  local sql = [[
      SELECT strftime("%s", datetime) * 1000 AS timestamp, temperature_in, temperature_out
      FROM weather
      WHERE temperature_out > -29.9 AND temperature_out < 69.9
      AND datetime > datetime('now', '-7 days')
  ]]

  --[[

  Required data format for flot JS charting library

  [ { label: "Foo", data: [ [10, 1], [17, -14], [30, 5] ] },
    { label: "Bar", data: [ [11, 13], [19, 11], [30, -7] ] } ]

  ]]--
  temp_in = {}
  temp_out = {}
  for row in self.db:nrows(sql) do
      temp_in[#temp_in + 1] = { row.timestamp, row.temperature_in }
      temp_out[#temp_out + 1] = { row.timestamp, row.temperature_out }
  end

  return {
      { label = "Inside Temperature",  data = temp_in  },
      { label = "Outside Temperature", data = temp_out }
  }
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
    WHERE date(datetime) < date('now')
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
    WHERE date(datetime) == date('now')
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
    local current_stmt = db:prepare[[
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

    if (current_stmt == nil) then
        print("Error preparing query: " .. db:errmsg())
        --db:close()
        --os.exit(1)
    end


    local obj = {
        db = db,
        current_stmt = current_stmt
    }

    return setmetatable(obj, meta)
end
