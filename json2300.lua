require("lsqlite3")
require("json")

local db_path = arg[1]
local json_path = arg[2]

if(not(db_path and json_path)) then
  print("Usage: json2300 db_path json_path")
  os.exit(2)
end

local db = sqlite3.open(db_path)

-- Current Weather Conditions
local stmt = db:prepare[[
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

if (stmt == nil) then
    print("Error preparing query: " .. db:errmsg())
    db:close()
    os.exit(1)
end

local weather = {}

for row in stmt:nrows() do
  weather.current = row
end

stmt:finalize()

-- Weather History
local sql = [[
    SELECT strftime("%s", datetime) * 1000 AS timestamp, temperature_in, temperature_out
    FROM weather
    WHERE temperature_out > -29.9 AND temperature_out < 69.9
]]

--[[

Required data format for flot JS charting library

[ { label: "Foo", data: [ [10, 1], [17, -14], [30, 5] ] },
  { label: "Bar", data: [ [11, 13], [19, 11], [30, -7] ] } ]

]]--
temp_in = {}
temp_out = {}
for row in db:nrows(sql) do
    temp_in[#temp_in + 1] = { row.timestamp, row.temperature_in }
    temp_out[#temp_out + 1] = { row.timestamp, row.temperature_out }
end
weather.history = {
    { label = "Inside Temperature",  data = temp_in  },
    { label = "Outside Temperature", data = temp_out }
}

-- Min Temperature
sql = [[
  SELECT strftime("%s", datetime) * 1000 AS timestamp, temperature_out
  FROM weather
  WHERE date(datetime) = (SELECT MAX(date(datetime)) FROM weather)
  AND temperature_out > -29.9 AND temperature_out < 69.9
  ORDER BY temperature_out ASC
  LIMIT 1
]]
for row in db:nrows(sql) do
  weather.current.min = {
    temperature = row.temperature_out,
    timestamp = row.timestamp
  }
end

-- Max Temperature
sql = [[
  SELECT strftime("%s", datetime) * 1000 AS timestamp, temperature_out
  FROM weather
  WHERE date(datetime) = (SELECT MAX(date(datetime)) FROM weather)
  AND temperature_out > -29.9 AND temperature_out < 69.9
  ORDER BY temperature_out DESC
  LIMIT 1
]]
for row in db:nrows(sql) do
  weather.current.max = {
    temperature = row.temperature_out,
    timestamp = row.timestamp
  }
end

db:close()

-- write out JSON
local jsonfile, err = io.open(json_path, "w")
if (jsonfile) then
  jsonfile:write(json.encode(weather))
  jsonfile:close()
else
  print("Unable to open JSON file for writing: " .. err)
end
