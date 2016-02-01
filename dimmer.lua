-- vim: ts=4 sw=4
--
-- timer used:
--	4: dimmer
--	5: reset
local dimmer={}
local pin=1 --GPIO_05
local val=2
local target=1
local pwms={
0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 6, 7, 7, 8, 9, 9, 10, 11, 11, 12, 13, 14, 15, 16, 17,
18, 20, 21, 23, 24, 26, 28, 30, 32, 34, 37, 39, 42, 45, 48, 52, 56, 60, 64, 69, 73, 79, 84, 90, 97, 104, 111, 119, 128, 137, 147,
157, 169, 181, 194, 208, 223, 239, 256, 274, 294, 315, 338, 362, 388, 416, 445, 477, 512, 548, 588, 630, 675, 723, 775, 831, 891,
955, 1023
}

function dimmer.init()
	pwm.setup(pin,500,val)
	pwm.start(pin)
	tmr.alarm(4, 1000, tmr.ALARM_AUTO, function()
		if target>val then
			val=val+1
			pwm.setduty(pin, pwms[val])
			print("set light level to: "..tostring(pwms[val]))
		elseif target<val then
			val=val-1
			pwm.setduty(pin, pwms[val])
			print("set light level to: "..tostring(pwms[val]))
		end
		collectgarbage()
	end)
end

function dimmer.set(val)
	target=val
	val=nil
	collectgarbage()
end

function dimmer.reset(timeout)
	tmr.alarm(5, timeout, tmr.ALARM_SINGLE, function()
		target=1
		print("dimmer timeout (light is now off)")
	end)
	timeout=nil
end

return dimmer
