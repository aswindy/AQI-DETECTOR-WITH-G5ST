--1.hcho等级【优，一般，有害】

require("LHC")

-- OLED Display demo
-- Variables 
sda = 5 -- SDA Pin
scl = 6 -- SCL Pin

wifi.sta.config("SSID","PASSWORD") --WIFI  SSID 及 密码

print(wifi.sta.getip())
sk=net.createConnection(net.TCP, 0) 


if wifi.sta.getip() == nil then
    print("Please Connect WIFI First")
    tmr.alarm(1,1000,1,function ()
        if wifi.sta.getip() ~= nil then
            tmr.stop(1)
            sk:dns("open.lewei50.com",function(conn,ip) 
            dns=ip
            print("DNS lewei50.com OK... IP: "..dns)
            end)
        end
    end)
end
LHC.init("01","USERKEY")  --乐为网关及USERKEY

function init_OLED(sda,scl) --Set up the u8glib lib
     sla = 0x3C
     i2c.setup(0, sda, scl, i2c.SLOW)
     
     disp = u8g.ssd1306_128x64_i2c(sla)
     disp:setFont(u8g.font_6x10)
     disp:setFontRefHeightExtendedText()
     disp:setDefaultForegroundColor()
     disp:setFontPosTop()
end


local sensorId
if(_G["sensorId"] ~= nil) then sensorId = _G["sensorId"]
else sensorId = "dust"
end
 


function print_OLED()  --显示模块
   disp:firstPage()
   repeat
     time = tmr.now
                disp:setDefaultForegroundColor()
               disp:drawFrame(0, 0, 128, 16)
               disp:drawStr(3,3, "GOOD")
               disp:drawStr(36,3, "NORMAL")
               disp:drawStr(82,3, "HARMFUL")
               
               disp:drawStr(3,33,"PM2.5: "..pm25.." ug/m3") 
               disp:drawStr(3,22,"HCHO : "..hcho.." mg/m3")
               disp:drawStr(3,44,"Temp : "..temp.." 'C") 
               disp:drawStr(3,55,"Humi : "..hum.." %")   
               hcholevel()
   until disp:nextPage() == false

end

function calcAQI(pNum)
     --local clow = {0,15.5,40.5,65.5,150.5,250.5,350.5}
     --local chigh = {15.4,40.4,65.4,150.4,250.4,350.4,500.4}
     --local ilow = {0,51,101,151,201,301,401}
     --local ihigh = {50,100,150,200,300,400,500}
     local ipm25 = {0,35,75,115,150,250,350,500}
     local laqi = {0,50,100,150,200,300,400,500}
     local result={"优","良","轻度污染","中度污染","重度污染","严重污染","爆表"}
     --print(table.getn(chigh))
     aqiLevel = 8
     for i = 1,table.getn(ipm25),1 do
          if(pNum<ipm25[i])then
               aqiLevel = i
               break
          end
     end
     --aqiNum = (ihigh[aqiLevel]-ilow[aqiLevel])/(chigh[aqiLevel]-clow[aqiLevel])*(pNum-clow[aqiLevel])+ilow[aqiLevel]
     aqiNum = (laqi[aqiLevel]-laqi[aqiLevel-1])/(ipm25[aqiLevel]-ipm25[aqiLevel-1])*(pNum-ipm25[aqiLevel-1])+laqi[aqiLevel-1]
     return math.floor(aqiNum),result[aqiLevel-1]
end

function hcholevel()  --甲醛等级模块

    if hcho<=0.08 then 
        disp:drawBox(0,0,32,16)
        disp:setDefaultBackgroundColor()
        disp:drawStr(3,3, "GOOD") 
    end

  
    if hcho<=0.1 and hcho >0.08 then 
        disp:drawBox(32,0,43,16)
        disp:setDefaultBackgroundColor()
        disp:drawStr(36,3, "NORMAL") 
    end
    if hcho<=0.5 and hcho >0.1  then 
        disp:drawBox(78,0,49,16)
        disp:setDefaultBackgroundColor()
        disp:drawStr(82,3, "HARMFUL") 
    end

end



function getSenserData()
    print_OLED()

end

aqi = 0
temp = 0
hum = 0
pm25 = 0
hcho = 0.000 

-- Main Program 
init_OLED(sda,scl) 

-----------------------------main-------------------------------------
tmr.alarm(0, 1000, 1, getSenserData) --读G5ST并显示/每秒刷新

tmr.alarm(1, 60000, 1, function()    --上传乐为/每分
               if hum ~= 0 then 
                   LHC.appendSensorValue("T1",temp) 
                   LHC.appendSensorValue("H1",hum)
                   LHC.appendSensorValue("hcho", hcho) 
                   aqi,result = calcAQI(pm25)
                   LHC.appendSensorValue("AQI",aqi)
                   LHC.sendSensorValue(sensorId,pm25) 
                           else
                   print("data not ready, wait...")
               end  
end)
----------------------------------------------------------------------

disp:firstPage()
repeat
disp:drawFrame(15,17,100,20) 
disp:drawStr(25,20,"AQI Detector") 
disp:drawStr(25,40,"Made by Yang") 
disp:drawStr(25,50,"Waitting....") 
until disp:nextPage() == false 


uart.setup( 0, 9600, 8, 0, 1, 0 )
uart.on("data", 0,
  function(data)
    gpio.write(0, gpio.LOW)
         if((string.len(data)==40) and (string.byte(data,1)==0x42) and (string.byte(data,2)==0x4d))  then
          pm25 = (string.byte(data,13)*256+string.byte(data,14))
          hcho = (string.byte(data,29)*256+string.byte(data,30))/1000
          temp = (string.byte(data,31)*256+string.byte(data,32))/10
          hum = (string.byte(data,33)*256+string.byte(data,34))/10

         end
    gpio.write(0, gpio.HIGH)
    
end, 0) 



  

