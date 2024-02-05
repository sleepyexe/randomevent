
RegisterCommand('test', function()
    for i = 1, 100 do
        TriggerRegisteredEvent('randomEvent', 'hello from client'..i)
    end
end)