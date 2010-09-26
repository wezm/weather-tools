require("lsqlite3")
require("json")

local db_path = arg[1]
local json_path = arg[2]

if(not(db_path and json_path)) then
  print("Usage: json2300 db_path json_path")
  os.exit(2)
end

local db = sqlite3.open(db_path)

local stmt = db:prepare[[
    SELECT *
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

-- Get the weather history
local sql = [[
    SELECT strftime("%s", datetime) * 1000, temperature_in, temperature_out
    FROM weather
]]

weather.history = {}
for row in db:rows(sql) do
    weather.history[#weather.history + 1] = row
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
