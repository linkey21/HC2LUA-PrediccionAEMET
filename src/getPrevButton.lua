--[[Prediccion-AEMET
	Dispositivo virtual
	getPrevButton.lua
	por Manuel Pascual
------------------------------------------------------------------------------]]
release = {name='prediccionAEMET getPrevButton', ver=0, mayor=0, minor=1}

--[[----- CONFIGURACION DE USUARIO -------------------------------------------]]

--[[----- FIN CONFIGURACION DE USUARIO ---------------------------------------]]

--[[----- NO CAMBIAR EL CODIGO A PARTIR DE AQUI ------------------------------]]

--[[----- CONFIGURACION AVANZADA ---------------------------------------------]]
-- obtener el ID de este dispositivo virtual
OFF=1;INFO=2;DEBUG=3		-- esto es una referencia para el log, no cambiar
nivelLog = INFO			-- nivel de log
--[[----- FIN CONFIGURACION AVANZADA -----------------------------------------]]

--[[
_log(level, log)
	funcion para operar el nivel de LOG
------------------------------------------------------------------------------]]
function _log(level, log)
  if log == nil then log = 'nil' end
  if nivelLog >= level then
    fibaro:debug(log)
  end
  return
end

--[[--------------------------------------------------------------------------]]

function _parseargs(s)
  local arg = {}
  string.gsub(s, "([%-%w]+)=([\"'])(.-)%2", function (w, _, a)
    arg[w] = a
  end)
  return arg
end

function _collect(s)
  local stack = {}
  local top = {}
  table.insert(stack, top)
  local ni,c,label,xarg, empty
  local i, j = 1, 1
  while true do
    ni,j,c,label,xarg, empty = string.find(s, "<(%/?)([%w:]+)(.-)(%/?)>", i)
    if not ni then break end
    local text = string.sub(s, i, ni-1)
    if not string.find(text, "^%s*$") then
      table.insert(top, text)
    end
    if empty == "/" then  -- empty element tag
      table.insert(top, {label=label, xarg=_parseargs(xarg), empty=1})
    elseif c == "" then   -- start tag
      top = {label=label, xarg=_parseargs(xarg)}
      table.insert(stack, top)   -- new level
    else  -- end tag
      local toclose = table.remove(stack)  -- remove top
      top = stack[#stack]
      if #stack < 1 then
        error("nothing to close with "..label)
      end
      if toclose.label ~= label then
        error("trying to close "..toclose.label.." with "..label)
      end
      table.insert(top, toclose)
    end
    i = j+1
  end
  local text = string.sub(s, i)
  if not string.find(text, "^%s*$") then
    table.insert(stack[#stack], text)
  end
  if #stack > 1 then
    error("unclosed "..stack[#stack].label)
  end
  return stack[1]
end

--[[--------------------------------------------------------------------------]]
function getPredictionTab(rawPredictionTab)
  local predictionTab = {}
  for rootKey, rootValue in pairs(rawPredictionTab) do
    if rootValue.label == 'root' then
      for predicKey, predicValue in pairs(rootValue) do
        if predicValue.label == 'prediccion' then
          for key, value in pairs(predicValue) do
            if value['label'] == 'dia' then
              --fibaro:debug(json.encode(value['xarg']))
              predictionTab[#predictionTab + 1] = value
            end
          end
        end
      end
    end
  end
  return predictionTab
end

--[[--------------------------------------------------------------------------]]
function formatDayPredictionTab(dayPredictionTab)
  local formatTempTab = {}
  local formatProbTab = {}
  local formatCotaTab = {}
  local formatEstaTab = {}
  local formatVienTab = {}
  local formatUv = 0
  -- para cada tipo de dato
  for key, value in pairs(dayPredictionTab) do
    -- obtener probavilidad de precipitacion
    if value['label'] == labelProbavilidad then
      if value[1] then
        formatProbTab[#formatProbTab + 1] = {periodo = value['xarg']['periodo'],
        valor = value[1]}
      end
    end
    -- obtener cota de nieve
    if value['label'] == labelCotaNieve then
      if value[1] then
        formatCotaTab[#formatCotaTab + 1] = {periodo = value['xarg']['periodo'],
        valor = value[1]}
      end
    end
    -- obtener estado del cielo
    if value['label'] == labelEstadoCielo then
      if value[1] then
        formatEstaTab[#formatEstaTab + 1] = {periodo = value['xarg']['periodo'],
        valor = value[1], descripcion = value['xarg']['descripcion']}
      end
    end
    -- obtener viento
    if value['label'] == labelViento then
      local direccion = value[1][1]
      local velocidad = value[2][1]
      local periodo = value['xarg']['periodo']
      formatVienTab[#formatVienTab + 1] = {periodo = periodo, direccion =
       direccion, velocidad = velocidad}
    end
    -- pasamos de obtener racha maxima
    -- obtener temperatura
    if value['label'] == labelTemperatura then
      formatTempTab = getFormatTempTab(value)
    end
    -- pasamos de obtener sensacion termica
    -- obtener indice de UV
    if value['label'] == labelIndUVMax then
      if value[1] then
        formatUv = value[1]
      end
    end
  end
  return {temperatura = formatTempTab, probLluvia = formatProbTab,
  			cotaNieve = formatCotaTab, estadoCielo = formatEstaTab,
  			viento = formatVienTab, indiceUV = formatUv}
end

--[[--------------------------------------------------------------------------]]
function getDayPredictionTab(predictionTab, timeStamp)
  -- obtener una tabla con la fecha de timestamp
  local timeStampTab = os.date("*t", timeStamp)
  -- inicializar una tabla para las fechas de las predicciones
  local predictionTimeTab = os.date("*t", timeStamp)
  -- para cada dia de la prediccion
  for key, value in pairs(predictionTab) do
    -- obtener la fecha de la prediccion
    local predictionDayTab = value['xarg']
    local predictionDate = predictionDayTab['fecha']
    -- insertar la fecha de la prediccion en su tabla
    predictionTimeTab['day'] = string.sub(predictionDate, 9, 10)
    predictionTimeTab['month'] = string.sub(predictionDate, 6, 7)
    predictionTimeTab['year'] = string.sub(predictionDate, 1, 4)
    -- comparar la tabla de la prediccion con la del timestamp
    -- si son iguales
    if os.time(predictionTimeTab) == os.time(timeStampTab) then
      -- devolver la tabla con la prevision del dia
      local myTab = {}
      -- recorrer la tabla para quitar la cabecera sin label
      for myKey, myValue in pairs(value) do
        if myValue.label then
          --fibaro:debug(json.encode(myValue))
          myTab[#myTab + 1] = myValue
        end
      end
      return formatDayPredictionTab(myTab)
    end
  end
  -- no hay coincidencia con ningun dia de la prevision
  return {}
end

--[[
_log(level, log)
Logger
------------------------------------------------------------------------------]]
function _log(level, log)
  if nivelLog >= level then
    fibaro:debug(log)
  end
  return
end

--[[
_inTable(tbl, item)
  función para saber si un item pertenece a la tabla
  tbl
  item
------------------------------------------------------------------------------]]
function _inTable(tbl, item)
  _log(DEBUG, '_inTable')
  for key, value in pairs(tbl) do
    if value == '*' or value == item then
      return true
    end
  end
  return false
end

--[[--------------------------------------------------------------------------]]
function getPeriodValue(myTab, hour)
  _log(DEBUG, 'getPeriodValue')
  for key, value in pairs (myTab) do
    if not _inTable({'00-24', '00-12', '12-24'}, value['periodo']) then
      local ini = tonumber(string.sub(value['periodo'], 1, 2))
      local fin = tonumber(string.sub(value['periodo'], 4, 5))
      if hour >= ini and hour < fin then
        if value.descripcion then
          return {valor = value.valor, descripcion = value.descripcion}
        elseif value.velocidad then
          return {direccion = value.direccion, velocidad = value.velocidad}
        else
          return value.valor
        end
      end
    end
   end
  return {}
end

--[[--------------------------------------------------------------------------]]
function getHourPredictionTab(dayPredictionTab, hour)
  hourPredictionTab = {}
  -- Probavilidad de precipitación
  hourPredictionTab['probLluvia'] =
  	getPeriodValue(dayPredictionTab.probLluvia, hour)
  -- Cota de nieve
  hourPredictionTab['cotaNieve'] =
  	getPeriodValue(dayPredictionTab.cotaNieve, hour)
  -- Estado del cielo
  hourPredictionTab['estadoCielo'] =
  	getPeriodValue(dayPredictionTab.estadoCielo, hour)
  -- Viento
  hourPredictionTab['viento'] =
  	getPeriodValue(dayPredictionTab.viento, hour)
  -- Temperatura
  _log(DEBUG, json.encode(dayPredictionTab.temperatura))
  -- ordenar la tabla para compara de menor a mayor
  table.sort(dayPredictionTab.temperatura.hora,
   function (a1, a2) return a1.hora < a2.hora; end)
  for key, value in pairs(dayPredictionTab.temperatura.hora) do
  	if hour <= tonumber(value.hora) then
  	  hourPredictionTab['temperatura'] = value.valor
  	end
  end
  -- Indice UV máximo
  hourPredictionTab['indiceUV'] = dayPredictionTab.indiceUV

  return hourPredictionTab
end

--[[--------------------------------------------------------------------------]]
function getFormatTempTab(tempTab)
  --
  local formatTempTab = {}
  local horaTab = {}
  for i = 1, #tempTab do
    --
    if tempTab[i].label == 'maxima' then
      -- obtener temperatura maxima
      formatTempTab['max'] = tempTab[i][1]
    end
    if tempTab[i].label == 'minima' then
      -- obtener temperatura minima
      formatTempTab['min'] = tempTab[i][1]
    end
    if tempTab[i].label == 'dato' then
      -- obtener la hora
      local hora = tempTab[i]['xarg']['hora']
      local temp = tempTab[i][1]
      horaTab[#horaTab + 1] = {hora = hora, valor = temp}
    end
  end
  formatTempTab['hora'] = horaTab
  return formatTempTab
end

--[[--------------------------------------------------------------------------]]
labelProbavilidad = 'prob'
labelCotaNieve = 'cota'
labelEstadoCielo = 'estado'
labelViento = 'viento'
labelTemperatura = 'temperatura'
labelIndUVMax = 'uv'
--[[--------------------------------------------------------------------------]]
-- obtener este dispositivo
local thisDev = fibaro:getSelfId()
-- variables para IP y puerto
local IPAddress = fibaro:getValue(thisDev, 'IPAddress')
local TCPPort = fibaro:getValue(thisDev, 'TCPPort')
-- componer la URL para leer los datos
local URL = '/xml/municipios/localidad_'..TCPPort..'.xml'
local http = Net.FHttp(IPAddress)

-- obtener tabla de predicciones
local predictionTab = getPredictionTab(_collect(http:GET(URL)))

-- obtener tabla de prediccion diaria de hoy
local dayPredictionTab = getDayPredictionTab(predictionTab, os.time())

-- obtener tabla de tiempo actual
local hora = tonumber(os.date('%H'))
local nowPredictionTab = getHourPredictionTab(dayPredictionTab, hora)

fibaro:debug(json.encode(nowPredictionTab))
--[[ formato de la tabla dayPredictionTab
dayPredictionTab =
	{indiceUV = 0, probLluvia = [{valor = 0, periodo =''}],
	 viento = [{direccion = '', velocidad = 0, periodo= ''},],
	 temperatura = {max = 0, min = 0, hora = {hora = 0, valor = 0}},
	 cotaNieve = {periodo = '', valor = 0},
	 estadoCielo = [{valor = 0, descripcion = '', periodo = ''}]}
--]]

-- asignar valores etiquetas
-- temperatura
fibaro:call(thisDev,"setProperty","ui.lbTemp.value",
dayPredictionTab.temperatura['min']..'/'..
dayPredictionTab.temperatura['max']..'ºC')

--[[
fibaro:debug('Probavilidad de precipitación')
fibaro:debug(json.encode(dayPredictionTab.probLluvia))

fibaro:debug('Cota de nieve')
fibaro:debug(json.encode(dayPredictionTab.cotaNieve))

fibaro:debug('Estado del cielo')
fibaro:debug(json.encode(dayPredictionTab.estadoCielo))

fibaro:debug('Viento')
fibaro:debug(json.encode(dayPredictionTab.viento))

fibaro:debug('Temperatura')
fibaro:debug(json.encode(dayPredictionTab.temperatura))

fibaro:debug('Indice UV máximo')
fibaro:debug(dayPredictionTab.indiceUV)

--]]
