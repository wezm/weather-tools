Weather Tools
=============

These scripts are used to extract information from an SQLite database of
weather observations. The database is populated by the [sqlitelog2300]
command in [my fork][open2300fork] of [Open2300][open2300]. The main script
is json2300.lua.

[sqlitelog2300]: http://github.com/wezm/open2300/blob/master/sqlitelog2300.c
[open2300]: http://www.lavrsen.dk/foswiki/bin/view/Open2300/WebHome
[open2300fork]: http://github.com/wezm/open2300

The temperature readings contain relatively frequent erroneous spikes, both
positive and negative. Attempts are made to filter these out.