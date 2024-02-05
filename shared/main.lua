local resourcesList = {}

for i = 1, GetNumResourceMetadata('randomevent', 'amankan') do
    local name = GetResourceMetadata('randomevent', 'amankan', i - 1)
    resourcesList[name] = true
end

local eventList = {}
local registeredEvent = {}
local rne = RegisterNetEvent

local IS_SERVER = IsDuplicityVersion()
local table_unpack = table.unpack
-- from scheduler.lua
local debug = debug
local debug_getinfo = debug.getinfo
local msgpack = msgpack
local msgpack_pack = msgpack.pack
local msgpack_unpack = msgpack.unpack
local msgpack_pack_args = msgpack.pack_args
-- from deferred.lua
local PENDING = 0
local RESOLVING = 1
local REJECTING = 2
local RESOLVED = 3
local REJECTED = 4
local resname = GetCurrentResourceName()
local charshet = {}
for i = 48, 57 do table.insert(charshet, string.char(i)) end
for i = 65, 90 do table.insert(charshet, string.char(i)) end
for i = 97, 122 do table.insert(charshet, string.char(i)) end

rne(('gir'):format(resname), function(cb)
    cb(GetInvokingResource())
end)

local function getSourceEvent()
    local pm = promise.new()
    TriggerEvent(('gir'):format(resname), function (res)
        pm:resolve(res)
    end)
    return Citizen.Await(pm)
end

local function randomEvent()
    Wait(0)
    local prefix, suffix = '', ''

    for i = 1, 4 do
        prefix = prefix .. charshet[math.random(1, #charshet)]
    end

    for i = 1, 15 do
        suffix = suffix .. charshet[math.random(1, #charshet)]
    end

    return prefix.. ':' ..suffix
end

-- custom function to check any type
local function ensure(obj, typeof, opt_typeof, errMessage)
	local objtype = type(obj)
	local di = debug_getinfo(2)
	local errMessage = errMessage or (opt_typeof == nil and (di.name .. ' expected %s, but got %s') or (di.name .. ' expected %s or %s, but got %s'))
	if typeof ~= 'function' then
		if objtype ~= typeof and objtype ~= opt_typeof then
			error((errMessage):format(typeof, (opt_typeof == nil and objtype or opt_typeof), objtype))
		end
	else
		if objtype == 'table' and not rawget(obj, '__cfx_functionReference') then
			error((errMessage):format(typeof, (opt_typeof == nil and objtype or opt_typeof), objtype))
		end
	end
end

if not IsDuplicityVersion() then
    local resname = GetCurrentResourceName()
    local SERVER_ID = GetPlayerServerId(PlayerId())
    local triggerServerEvent = TriggerServerEvent

    TriggerServerCallback = function(args)
		ensure(args, 'table'); ensure(args.args, 'table', 'nil'); ensure(args.eventName, 'string'); ensure(args.timeout, 'number', 'nil'); ensure(args.timedout, 'function', 'nil'); ensure(args.callback, 'function', 'nil')
		
		-- create a new promise
		local prom = promise.new()
		-- save the callback function on this call
		local eventCallback = args.callback
		-- save the event data to remove it when resolved
		local eventData = RegisterNetEvent(('security_response:%s:%s'):format(args.eventName, SERVER_ID),
		function(packed)
			-- check if this call is async
			-- & the promise wasn't rejected or resolved
			if eventCallback and prom.state == PENDING then eventCallback( table_unpack(msgpack_unpack(packed)) ) end
			prom:resolve( table_unpack(msgpack_unpack(packed)) )

		end)

		-- fire the callback event
		TriggerServerEvent('security_server:'..args.eventName, msgpack_pack( args.args ))

		-- timeout response
		if args.timeout ~= nil and args.timedout then
			local timedout = args.timedout
			SetTimeout(args.timeout * 1000, function()
				-- check if the promise wasn't resolved yet
				if
					prom.state == PENDING or
					prom.state == REJECTED or
					prom.state == REJECTING
				then
					-- call the timeout callback
					timedout(prom.state)
					-- reject the promise if it wasn't rejected
					if prom.state == PENDING then prom:reject() end
					-- remove the event handler
					RemoveEventHandler(eventData)
				end
			end)
		end

		-- check if this call is async
		if not eventCallback then
			local result = Citizen.Await(prom)
			-- remove the event handler
			RemoveEventHandler(eventData)
			return result
		end
	end

    function TriggerRegisteredEvent(name, ...)
        if not resourcesList[resname] then
            print('This Resources Is Not Allowed')
            return
        end
        Wait(100)
        local request = TriggerServerCallback({
            eventName = ('getEvent/%s'):format(resname),
            args = {name},
            timeout = 10000,
        })
        if not request then print('Invalid Event') return end
        print(request)
        triggerServerEvent(request, ...)
        return
    end

else
    local resname = GetCurrentResourceName()
    local RegisterServerCallback = function(args)
		ensure(args, 'table'); ensure(args.eventName, 'string'); ensure(args.eventCallback, 'function')
        print('registered', args.eventName)
		-- save the callback function on this call
		local eventCallback = args.eventCallback
		-- save the event name on this call
		local eventName = args.eventName
		-- save the event data to return
		local eventData = RegisterNetEvent('security_server:'..eventName, function(packed, src, cb)
			-- save the source on this call
			local source = tonumber(source)
			-- check if this is a simulated callback (TriggerServerCallback)
            local invoker = getSourceEvent()
            if not resourcesList[invoker] then
                print(('%s Trying To Trigger %s, But Not Allowed'):format(invoker, eventName))
                return
            end
			if not source then
				-- return the simulated data
				cb( msgpack_pack_args( eventCallback(src, table_unpack(msgpack_unpack(packed)) ) ) )
			else
				-- return the data
				TriggerClientEvent(('security_response:%s:%s'):format(eventName, source), source, msgpack_pack_args( eventCallback(source, table_unpack(msgpack_unpack(packed)) ) ))
			end
		end)
		-- return the event data to UnregisterServerCallback
		return eventData
	end
    RegisterServerCallback({
        eventName = ('getEvent/%s'):format(resname),
        eventCallback = function(serverId, name)
            Wait(100)
            return eventList[name]
        end
    })

    function RegisterRandomEvent(name, cb)
        local event = randomEvent()
        eventList[name] = event
        Wait(100)
        local registered = rne(event, function(...)
            local invoker = getSourceEvent()
            if not resourcesList[invoker] then
                print(('%s Trying To Trigger %s, But Not Allowed'):format(invoker, name))
                return
            end
            cb(...)
            RemoveEventHandler(registeredEvent[name])
            return RegisterRandomEvent(name, cb)
        end)
        registeredEvent[name] = registered
        Wait(100)
    end
end