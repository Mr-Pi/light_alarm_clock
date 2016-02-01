-- vim: ts=4 sw=4
local time={}
local TZ=0

local dpm={31,28,31,30,31,30,31,31,30,31,30,31}

function time.getHour(timestamp)
	return math.floor(timestamp%(86400)/3600)+TZ
end

function time.getMinute(timestamp)
	return math.floor(timestamp%3600/60)
end

function time.getSecond(timestamp)
	return timestamp%60
end

function time.getWeekday(timestamp)
	return math.floor((timestamp+3*86400)/86400)%7 -- 0 is monday
end

function time.getYear(timestamp)
	return math.floor(timestamp/(86400*365))+1970
end

function time.getMonth(timestamp)
end

function time.isLeapYear(timestamp)
	local y=time.getYear(timestamp)
	local leapyear=false
	if y%4==0 and y%100~=0 then
		leapyear=true
	elseif y%400==0 then
		leapyear=true
	end
	y=nil
	collectgarbage()
	return leapyear
end

function time.get(timestamp)
	return
		time.getHour(timestamp),
		time.getMinute(timestamp),
		time.getSecond(timestamp),
		time.getWeekday(timestamp)
end

return time
