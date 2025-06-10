--[[
OpenMEteo weather station
@author ikubicki+damasant
@version 1.0.0
]]

function QuickApp:onInit()
    self:initializeProperties()
    self:initializeChildren()
    self:trace('')
    self:trace(self.i18n:get('name'))
    GUI:label2Render()
    GUI:button3Render()
    self:run()
end

function QuickApp:run()
    self:pullOpenMeteoData()
    if (self.interval > 0) then
        fibaro.setTimeout(self.interval, function() self:run() end)
    end
end

function QuickApp:button1Event()
    self:run()
end

function QuickApp:pullOpenMeteoData()
    self.gui:button1Text('please-wait')

    local callback = function(response)
        if not response or not response.data or response.data == "" then
            self:error("Empty response from server")
            self.gui:label1Text("Error retrieving data")
            self.gui:button1Text('retry')
            return
        end

        local data = json.decode(response.data)
        if not data or not data.current_weather then
            self:error("Unexpected data format from OpenMeteo")
            self.gui:label1Text("Error de datos")
            self.gui:button1Text('retry')
            return
        end

        self:updateProvider(data)
        self:updateDevices(data)
        self:updateSunInfo(data)
        self:updateViewElements()
    end

    self.http:get(self:getUrlQueryString(), callback)
end

function QuickApp:updateViewElements()
    self.gui:label1Text('last-update', os.date('%Y-%m-%d %H:%M:%S'))
    self.gui:button1Text('refresh')
end

function QuickApp:updateProvider(data)
    local weather = data.current_weather
    self:updateProperty("WeatherCondition", tostring(weather.weathercode))
    self:updateProperty("ConditionCode", tostring(weather.weathercode))
    self:updateProperty("Temperature", weather.temperature)
    self:updateProperty("Humidity", data.daily.relative_humidity_2m_max and data.daily.relative_humidity_2m_max[1])
    self:updateProperty("Wind", weather.windspeed)
    self:updateProperty("Pressure", data.daily.surface_pressure_max and data.daily.surface_pressure_max[1])
end

function QuickApp:updateDevices(data)
    local weather = data.current_weather
    
    -- TEMPERATURE
    OWTemperature:get('temperature'):update({value = weather.temperature})
    -- WIND
    OWWind:get('wind'):update({value = weather.windspeed, unit = 'km/h'})
    -- PRESSURE
    OWSensor:get('pressure'):update({value = data.daily.surface_pressure_max and data.daily.surface_pressure_max[1], unit = 'mbar'})
    -- HUMIDITY
    OWHumidity:get('humidity'):update({value = data.daily.relative_humidity_2m_max and data.daily.relative_humidity_2m_max[1], unit = '%'})
    -- CLOUDS
    OWSensor:get('clouds'):update({value = data.daily.cloudcover and data.daily.cloudcover[1], unit = '%'})
    -- RAIN
    OWRain:get('rain'):update({value = 0, unit = 'mm'})  -- Open-Meteo solo si pides lluvia diaria
    -- UVI
    if data.daily.uv_index_max then
        OWSensor:get('uv'):update(data.daily.uv_index_max[1])
    end
end

function QuickApp:updateSunInfo(data)
    -- SUNRISE
    local sunrise = data.daily.sunrise and data.daily.sunrise[1]
    if sunrise then
        local hour = tonumber(os.date('%H.%M', os.time({year=string.sub(sunrise,1,4), month=string.sub(sunrise,6,7), day=string.sub(sunrise,9,10), hour=string.sub(sunrise,12,13), min=string.sub(sunrise,15,16)})))
        OWSensor:get('sunrise'):update(hour)
    end

    -- SUNSET
    local sunset = data.daily.sunset and data.daily.sunset[1]
    if sunset then
        local hour = tonumber(os.date('%H.%M', os.time({year=string.sub(sunset,1,4), month=string.sub(sunset,6,7), day=string.sub(sunset,9,10), hour=string.sub(sunset,12,13), min=string.sub(sunset,15,16)})))
        OWSensor:get('sunset'):update(hour)
    end
end

function QuickApp:toggleMetric(e)
    if e.elementName == 'button3_1' then Toggles:toggle('temperature') end
    if e.elementName == 'button3_2' then Toggles:toggle('wind') end
    if e.elementName == 'button3_3' then Toggles:toggle('pressure') end
    if e.elementName == 'button3_4' then Toggles:toggle('humidity') end
    if e.elementName == 'button3_5' then Toggles:toggle('clouds') end
    if e.elementName == 'button3_6' then Toggles:toggle('rain') end
    if e.elementName == 'button3_7' then Toggles:toggle('uv') end
    if e.elementName == 'button3_8' then Toggles:toggle('sunrise') end
    if e.elementName == 'button3_9' then Toggles:toggle('sunset') end
    GUI:button3Render()
    GUI:button1Text('refresh-sensors')
end

function QuickApp:getUrlQueryString()
    local query = string.format(
        "/forecast?latitude=%s&longitude=%s&current_weather=true&daily=sunrise,sunset,uv_index_max&timezone=auto",
        self.latitude,
        self.longitude
    )
    return query
end


function QuickApp:initializeProperties()
    local locationInfo = api.get('/settings/location')
    self.latitude = locationInfo.latitude
    self.longitude = locationInfo.longitude
    self.apikey = self:getVariable("APIKEY")
    self.interval = 1

    QuickApp.toggles = Toggles:new()
    QuickApp.i18n = i18n:new(api.get("/settings/info").defaultLanguage)
    QuickApp.gui = GUI:new(self, QuickApp.i18n)
    QuickApp.builder = DeviceBuilder:new(self)
    QuickApp.http = HTTPClient:new({
        baseUrl = 'https://api.open-meteo.com/v1'
    })

    self:updateProperty('manufacturer', 'OpenMeteo')
    self:updateProperty('model', 'Weather provider')

    -- hours to miliseconds conversion
    self.interval = self:hoursToMiliseconds(self.interval)
end

function QuickApp:hoursToMiliseconds(hours)
    return hours * 3600000
end

function QuickApp:initializeChildren()
    self.builder:initChildren({
        [OWSensor.class] = OWSensor,
        [OWTemperature.class] = OWTemperature,
        [OWWind.class] = OWWind,
        [OWHumidity.class] = OWHumidity,
        [OWRain.class] = OWRain,
    })
end
