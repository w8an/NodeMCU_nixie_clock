---------------------------------
-- NodeMCU Nixie Clock
--
-- LICENCE: http://opensource.org/licenses/MIT
-- Steven R. Stuart
---------------------------------

-- Wifi
SSID,PSWD = "wifi ssid","wifi password"
NTP_HOST = "us.pool.ntp.org"

-- I2C bus pin connections
SDA = 1 --GPIO5(D1)
SCL = 2 --GPIO4(D2)

-- Time zone - seconds offset from utc
UTC = 0 
EDT = -14400 --eastern daylight time
EST = -18000 --eastern standard time
PDT = -25200 --pacific daylight
PST = -28800 --pacific standard

TZ = EST     --my time zone

-- Multiplexer rate in millisec
--  lower value reduces flicker
--  too low and NodeMCU will crash
MPX_MS = 6

-- I/O port expander constants
MCP23017_ID = 0        --i2c id
MCP23017_ADDR = 0x20   --i2c address
MCP23017_OLATA = 0x12  --output latch banks regs
MCP23017_OLATB = 0x13
MCP23017_IODIRA = 0x00 --I/O direction regs
MCP23017_IODIRB = 0x01

NIXIE_SEGM = MCP23017_OLATA --bcd numeral port
NIXIE_TUBE = MCP23017_OLATB --tube position port

-- Time & date number format:
--  midnite = 0, noon = 120000, 3:45:27PM = 154527
--  jan 6, 2017 = 1062017 
time_val = 0
date_val = 0

-- Initalize the i/o expander
function mcp23017_init(sda,scl) 
  i2c.setup(MCP23017_ID, sda, scl, i2c.SLOW)
  writeReg(MCP23017_IODIRA, 0x00) -- set bank A to output
  writeReg(MCP23017_IODIRB, 0x00) -- set bank B to output 
end

-- Write value to i/o expander register
function writeReg(reg, val)
  i2c.start(MCP23017_ID)
  i2c.address(MCP23017_ID, MCP23017_ADDR, i2c.TRANSMITTER)
  i2c.write(MCP23017_ID, reg)
  i2c.write(MCP23017_ID, val)
  i2c.stop(MCP23017_ID)
end

-- Clock logic          
function timeTick()  
  local h = time_val / 10000 --set initial clock upvalues
  local m = time_val / 100 - time_val / 10000 * 100
  local s = time_val - time_val / 100 * 100
  return function ()         --must call every second
    s = s + 1
    if s == 60 then
      s = 0; m = m + 1
      if m == 60 then m = 0; h = h + 1
        if h == 24 then h = 0 end
      end
    end
    return h * 10000 + m * 100 + s --updated time val
  end
end

-- Get current time from network ntp host
function getNtpTime()
  sntp.sync(NTP_HOST)  
  local rtc = rtctime.get()
  local tm = rtctime.epoch2cal(rtc + TZ) --convert to calendar format
  return tm["hour"] * 10000 + tm["min"] * 100 + tm["sec"], 
    tm["mon"] * 1000000 + tm["day"] * 10000 + tm["year"]
end

-- Multiplex the Nixie tubes
function mplexOutput()
  local pos,t,t1 = 1,time_val,0 --tube position and time work vars
  return function () 
    t1 = t / 10              --isolate next time digit
    t = t - t1 * 10
    writeReg(NIXIE_SEGM,0xF) --blank the tube
    writeReg(NIXIE_TUBE,pos) --select next tube position
    writeReg(NIXIE_SEGM,t)   --light up the tube digit
    t = t1                   --get the remaining time val digits
    pos = pos * 2            --rotate to next tube position left
    if pos == 64 then        --reset tube position and
      pos,t = 1,time_val     --reload time val
    end  
  end                                     
end

-- Connect to wifi
wifi.setmode(wifi.STATION)   
wifi.sta.config(SSID,PSWD)
wifi.sta.connect()

-- Set up clock
mcp23017_init(SDA,SCL)       --initialize i2c and port expander
time_val,date_val = getNtpTime()    --get current time
tmTick = timeTick()          --initialize time counter
mplex = mplexOutput()        --initialize nixie multiplexer

-- Run Nixie display multiplexer
tmr.alarm(0, MPX_MS, tmr.ALARM_AUTO, --millisecond per tube
  function()  
    mplex()                  --light up the next tube
  end
)

-- Update time every second
tmr.alarm(1, 1000, tmr.ALARM_AUTO, --1 sec
  function()
    time_val = tmTick()      --add 1 second
  end
)

-- Set the clock every 90 minutes
tmr.alarm(2, 5400000, tmr.ALARM_AUTO,   
  function() 
    time_val,date_val = getNtpTime() --update time values
    tmTick = timeTick()          --set the upvalues
  end
)  

